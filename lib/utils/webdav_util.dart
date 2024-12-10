import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' as flutter;
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/values/webdav.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../common/models/isar/diary.dart';

class WebDavUtil {
  RxSet<String> syncingDiaries = <String>{}.obs;

  webdav.Client? _client;

  List<String> get options => Utils().prefUtil.getValue<List<String>>('webDavOption')!;

  bool get hasOption => Utils().prefUtil.getValue<List<String>>('webDavOption')!.isNotEmpty;

  Future<void> initWebDav() async {
    final webDavOption = options;
    if (webDavOption.isEmpty) {
      _client = null;
      return;
    }
    if (_client != null) {
      _client = null;
    }
    _client =
        webdav.newClient(webDavOption[0], user: webDavOption[1], password: webDavOption[2], debug: flutter.kDebugMode);
    _client?.setHeaders({
      'accept-charset': 'utf-8',
      'Content-Type': 'application/json',
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      await _client?.ping();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> initDir() async {
    await _client!.mkdirAll(WebDavOptions.imagePath);
    await _client!.mkdirAll(WebDavOptions.videoPath);
    await _client!.mkdirAll(WebDavOptions.audioPath);
    await _client!.mkdirAll(WebDavOptions.diaryPath);
    await _client!.mkdirAll(WebDavOptions.categoryPath);
    await checkSyncFlag();
  }

  Future<void> checkSyncFlag() async {
    try {
      await _client!.read(WebDavOptions.syncFlagPath);
    } catch (e) {
      await _client!.write(WebDavOptions.syncFlagPath, utf8.encode(jsonEncode({})));
    }
  }

  Future<void> updateWebDav({required String baseUrl, required String username, required String password}) async {
    await Utils().prefUtil.setValue('webDavOption', [baseUrl, username, password]);
    initWebDav();
  }

  Future<void> removeWebDavOption() async {
    _client = null;
    await Utils().prefUtil.setValue<List<String>>('webDavOption', []);
  }

  Future<Map<String, String>> fetchServerSyncData() async {
    if (_client != null) {
      final response = await _client!.read(WebDavOptions.syncFlagPath);
      if (response.isNotEmpty) {
        return Map<String, String>.from(jsonDecode(utf8.decode(response)));
      }
    }
    return {};
  }

  Future<void> updateServerSyncData(Map<String, String> syncData) async {
    if (_client != null) {
      await _client!.write(WebDavOptions.syncFlagPath, utf8.encode(jsonEncode(syncData)));
    }
  }

  Future<void> syncDiary(
    List<Diary> localDiaries, {
    flutter.VoidCallback? onUpload,
    flutter.VoidCallback? onDownload,
    flutter.VoidCallback? onComplete,
  }) async {
    final serverSyncData = await fetchServerSyncData();
    final Map<String, String> updatedSyncData = {...serverSyncData};

    // 本地日记的 ID -> 修改时间映射
    final Map<String, String> localDiaryMap = {
      for (final diary in localDiaries) diary.id: diary.lastModified.toIso8601String()
    };

    for (final entry in serverSyncData.entries) {
      final diaryId = entry.key;
      final serverLastModified = entry.value;

      if (syncingDiaries.contains(diaryId)) {
        continue; // 正在同步中，跳过
      }

      final localLastModified = localDiaryMap[diaryId];

      if (localLastModified == null || serverLastModified.compareTo(localLastModified) > 0) {
        // 本地不存在该日记，下载
        syncingDiaries.add(diaryId);
        final updatedDiary = await _downloadDiary(diaryId); // 下载日记的实现
        await _saveLocalDiary(updatedDiary); // 保存到本地的实现
        onDownload?.call();
        syncingDiaries.remove(diaryId);
      }
    }

    for (final diary in localDiaries) {
      if (syncingDiaries.contains(diary.id)) {
        continue; // 正在同步中，跳过
      }

      final serverLastModified = serverSyncData[diary.id];
      final localLastModified = diary.lastModified.toIso8601String();

      if (serverLastModified == null || serverLastModified.compareTo(localLastModified) < 0) {
        // 服务器不存在该日记，或服务器版本较旧
        syncingDiaries.add(diary.id);
        await _uploadDiary(diary); // 上传日记的实现
        onUpload?.call();
        updatedSyncData[diary.id] = localLastModified;
        syncingDiaries.remove(diary.id);
      }
    }

    // 更新服务器的同步 JSON 文件
    await updateServerSyncData(updatedSyncData);
    onComplete?.call();
  }

  Future<void> uploadSingleDiary(
    Diary diary, {
    flutter.VoidCallback? onUpload,
    flutter.VoidCallback? onComplete,
  }) async {
    if (syncingDiaries.contains(diary.id)) {
      return; // 避免重复上传
    }

    syncingDiaries.add(diary.id);
    try {
      // 上传日记到服务器
      await _uploadDiary(diary); // 上传日记的实现

      // 更新服务器同步数据
      final serverSyncData = await fetchServerSyncData();
      serverSyncData[diary.id] = diary.lastModified.toIso8601String();
      await updateServerSyncData(serverSyncData);

      onUpload?.call();
    } catch (e) {
      Utils().logUtil.printInfo('Failed to upload diary: $e');
    } finally {
      syncingDiaries.remove(diary.id);
      onComplete?.call(); // 调用完成回调
    }
  }

  Future<void> _uploadDiary(Diary diary) async {
    // 检查并上传分类
    if (diary.categoryId != null) {
      final categoryName = Utils().isarUtil.getCategoryName(diary.categoryId!)?.categoryName;
      if (categoryName != null) {
        await _uploadCategory(diary.categoryId!, categoryName);
      }
    }

    // 上传日记 JSON 数据
    final diaryPath = '${WebDavOptions.diaryPath}/${diary.id}.json';
    final diaryData = jsonEncode(diary.toJson());

    try {
      _client!.setHeaders({
        'accept-charset': 'utf-8',
        'Content-Type': 'application/json',
      });
      await _client!.write(diaryPath, utf8.encode(diaryData));
      Utils().logUtil.printInfo('Diary JSON uploaded: $diaryPath');
    } catch (e) {
      Utils().logUtil.printInfo('Failed to upload diary JSON: $e');
      rethrow;
    }

    // 上传资源文件
    await _uploadFiles(diary.imageName, WebDavOptions.imagePath, 'image');
    await _uploadFiles(diary.audioName, WebDavOptions.audioPath, 'audio');
    await _uploadFiles(diary.videoName, WebDavOptions.videoPath, 'video');
  }

  Future<void> _uploadFiles(List<String> fileNames, String resourcePath, String type) async {
    // 检查服务器是否已经存在该文件
    final existingFiles = await _client!.readDir(resourcePath);

    for (final fileName in fileNames) {
      final filePath = Utils().fileUtil.getRealPath(type, fileName);
      if (existingFiles.any((file) => file.name == fileName)) {
        Utils().logUtil.printInfo('$type file already exists: $fileName');
        continue;
      }
      try {
        final fileBytes = await File(filePath).readAsBytes();
        _client!.setHeaders({
          'accept-charset': 'utf-8',
          'Content-Type': 'application/octet-stream',
        });
        await _client!.write('$resourcePath/$fileName', fileBytes);
        Utils().logUtil.printInfo('$type file uploaded: $fileName');
      } catch (e) {
        Utils().logUtil.printInfo('Failed to upload $type file: $fileName, Error: $e');
        rethrow;
      }
    }
  }

  Future<Diary> _downloadDiary(String diaryId) async {
    // 下载日记 JSON 数据
    final diaryPath = '${WebDavOptions.diaryPath}/$diaryId.json';
    late Diary diary;

    try {
      final diaryData = await _client!.read(diaryPath);
      diary = Diary.fromJson(jsonDecode(utf8.decode(diaryData)));
      Utils().logUtil.printInfo('Diary JSON downloaded: $diaryPath');
    } catch (e) {
      Utils().logUtil.printInfo('Failed to download diary JSON: $e');
      rethrow;
    }

    // 同步分类
    if (diary.categoryId != null) {
      try {
        final category = await _downloadCategory(diary.categoryId!);
        Utils().isarUtil.insertACategory(Category()
          ..id = category['id']!
          ..categoryName = category['name']!);
      } catch (e) {
        Utils().logUtil.printInfo('Failed to sync category for diary: $diaryId, Error: $e');
      }
    }

    // 下载资源文件
    diary.imageName = await _downloadFiles(diary.imageName, WebDavOptions.imagePath, 'image');
    diary.audioName = await _downloadFiles(diary.audioName, WebDavOptions.audioPath, 'audio');
    diary.videoName = await _downloadFiles(diary.videoName, WebDavOptions.videoPath, 'video');

    return diary;
  }

  Future<List<String>> _downloadFiles(List<String> fileNames, String resourcePath, String type) async {
    final localFileNames = <String>[];

    for (final fileName in fileNames) {
      final serverFilePath = '$resourcePath/$fileName';
      final localFilePath = Utils().fileUtil.getRealPath(type, fileName);

      try {
        final fileBytes = await _client!.read(serverFilePath);
        final file = File(localFilePath);
        await file.writeAsBytes(fileBytes);
        localFileNames.add(fileName);
        Utils().logUtil.printInfo('$type file downloaded: $fileName');
      } catch (e) {
        Utils().logUtil.printInfo('Failed to download $type file: $fileName, Error: $e');
      }
    }

    return localFileNames;
  }

  Future<void> _saveLocalDiary(Diary diary) async {
    // 使用 Isar 或文件存储
    await Utils().isarUtil.insertADiary(diary);
  }

  Future<void> _uploadCategory(String categoryId, String categoryName) async {
    final categoryPath = '${WebDavOptions.categoryPath}/$categoryId.json';
    final categoryData = jsonEncode({'id': categoryId, 'name': categoryName});

    try {
      _client!.setHeaders({
        'accept-charset': 'utf-8',
        'Content-Type': 'application/json',
      });
      await _client!.write(categoryPath, utf8.encode(categoryData));
      Utils().logUtil.printInfo('Category uploaded: $categoryPath');
    } catch (e) {
      Utils().logUtil.printInfo('Failed to upload category: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _downloadCategory(String categoryId) async {
    final categoryPath = '${WebDavOptions.categoryPath}/$categoryId.json';

    try {
      final categoryData = await _client!.read(categoryPath);
      final categoryMap = jsonDecode(utf8.decode(categoryData)) as Map<String, dynamic>;
      final categoryName = categoryMap['name'] as String;
      Utils().logUtil.printInfo('Category downloaded: $categoryPath');
      return {'id': categoryId, 'name': categoryName};
    } catch (e) {
      Utils().logUtil.printInfo('Failed to download category: $e');
      throw Exception('Category not found: $categoryId');
    }
  }
}
