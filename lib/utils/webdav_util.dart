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
    if (_client == null) {
      return false;
    }
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

  //删除某一篇日记，将webdav中sync.json的对应日记id的value设置为delete
  Future<void> deleteSingleDiary(Diary diary) async {
    final serverSyncData = await fetchServerSyncData();
    if (!serverSyncData.containsKey(diary.id)) {
      return;
    }
    serverSyncData[diary.id] = 'delete';
    await updateServerSyncData(serverSyncData);
    // 删除日记json
    await _client!.remove('${WebDavOptions.diaryPath}/${diary.id}.json');
    // 遍历删除日记资源文件
    await _deleteFiles(diary.imageName, WebDavOptions.imagePath, 'image');
    await _deleteFiles(diary.audioName, WebDavOptions.audioPath, 'audio');
    await _deleteFiles(diary.videoName, WebDavOptions.videoPath, 'video');
    await _deleteFiles(diary.videoName.map((videoName) => 'thumbnail-${videoName.substring(6, 42)}.jpeg').toList(),
        WebDavOptions.videoPath, 'thumbnail');
    // 删除对应目录
    await _client!.remove('${WebDavOptions.imagePath}/${diary.id}');
    await _client!.remove('${WebDavOptions.audioPath}/${diary.id}');
    await _client!.remove('${WebDavOptions.videoPath}/${diary.id}');
  }

  Future<void> _deleteDiary(Diary diary) async {
    // 删除文件的通用方法
    Future<void> deleteFiles(List<String> names, String folder) async {
      final tasks =
          names.map((name) => Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath(folder, name))).toList();
      await Future.wait(tasks);
    }

    // 删除日记和关联文件
    if (await Utils().isarUtil.deleteADiary(diary.isarId)) {
      // 并行删除图片、音频、视频及其缩略图
      await Future.wait([
        deleteFiles(diary.imageName, 'image'),
        deleteFiles(diary.audioName, 'audio'),
        deleteFiles(diary.videoName, 'video'),
        deleteFiles(diary.videoName, 'thumbnail'), // 视频缩略图
      ]);
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
      //如果本地还有日记，但服务器中的日记已经被删除
      if (serverLastModified == 'delete') {
        if (localLastModified != null) {
          syncingDiaries.add(diaryId);
          await _deleteDiary(localDiaries.firstWhere((element) => element.id == diaryId));
          syncingDiaries.remove(diaryId);
        }
        continue;
      }

      //本地不存在该日记，下载
      if (localLastModified == null) {
        syncingDiaries.add(diaryId);
        final updatedDiary = await _downloadDiary(diaryId); // 下载日记的实现
        await Utils().isarUtil.insertADiary(updatedDiary); // 保存到本地的实现
        onDownload?.call();
        syncingDiaries.remove(diaryId);
      }
      // 本地存在该日记，但服务器版本较新，更新本地
      if (localLastModified != null && serverLastModified.compareTo(localLastModified) > 0) {
        syncingDiaries.add(diaryId);
        final oldDiary = localDiaries.firstWhere((element) => element.id == diaryId);
        final newDiary = await _downloadDiary(diaryId);
        await Utils().isarUtil.updateADiary(oldDiary: oldDiary, newDiary: newDiary);
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

  Future<void> updateSingleDiary({
    required Diary oldDiary,
    required Diary newDiary,
    flutter.VoidCallback? onUpload,
    flutter.VoidCallback? onComplete,
  }) async {
    if (syncingDiaries.contains(newDiary.id)) {
      return; // 避免重复上传
    }
    syncingDiaries.add(newDiary.id);
    try {
      // 遍历删除日记资源文件
      final needToDeleteImage = oldDiary.imageName.where((element) => !newDiary.imageName.contains(element)).toList();
      final needToDeleteAudio = oldDiary.audioName.where((element) => !newDiary.audioName.contains(element)).toList();
      final needToDeleteVideo = oldDiary.videoName.where((element) => !newDiary.videoName.contains(element)).toList();
      final needToDeleteThumbnail =
          needToDeleteVideo.map((videoName) => 'thumbnail-${videoName.substring(6, 42)}.jpeg').toList();
      await _deleteFiles(needToDeleteImage, WebDavOptions.imagePath, 'image');
      await _deleteFiles(needToDeleteAudio, WebDavOptions.audioPath, 'audio');
      await _deleteFiles(needToDeleteVideo, WebDavOptions.videoPath, 'video');
      await _deleteFiles(needToDeleteThumbnail, WebDavOptions.videoPath, 'thumbnail');
      // 上传日记到服务器
      await _uploadDiary(newDiary); // 上传日记的实现
      // 更新服务器同步数据
      final serverSyncData = await fetchServerSyncData();
      serverSyncData[newDiary.id] = newDiary.lastModified.toIso8601String();
      await updateServerSyncData(serverSyncData);
      onUpload?.call();
    } catch (e) {
      Utils().logUtil.printInfo('Failed to upload diary: $e');
    } finally {
      syncingDiaries.remove(newDiary.id);
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
    Utils().logUtil.printInfo(diaryData);
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

    // 上传资源文件，目标路径是资源文件夹下的日记id
    await _uploadFiles(diary.imageName, '${WebDavOptions.imagePath}/${diary.id}', 'image');
    await _uploadFiles(diary.audioName, '${WebDavOptions.audioPath}/${diary.id}', 'audio');
    await _uploadFiles(diary.videoName, '${WebDavOptions.videoPath}/${diary.id}', 'video');
    await _uploadFiles(diary.videoName, '${WebDavOptions.videoPath}/${diary.id}', 'thumbnail');
  }

  Future<void> _uploadFiles(List<String> fileNames, String resourcePath, String type) async {
    await _client!.mkdirAll(resourcePath);
    final existingFiles = await _client!.readDir(resourcePath);

    for (var fileName in fileNames) {
      final filePath = Utils().fileUtil.getRealPath(type, fileName);
      fileName = type == 'thumbnail' ? 'thumbnail-${fileName.substring(6, 42)}.jpeg' : fileName;
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

  Future<void> _deleteFiles(List<String> fileNames, String resourcePath, String type) async {
    for (final fileName in fileNames) {
      try {
        await _client!.remove('$resourcePath/$fileName');
        Utils().logUtil.printInfo('$type file deleted: $fileName');
      } catch (e) {
        Utils().logUtil.printInfo('Failed to delete $type file: $fileName, Error: $e');
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
        await Utils().isarUtil.updateACategory(Category()
          ..id = category['id']!
          ..categoryName = category['name']!);
      } catch (e) {
        Utils().logUtil.printInfo('Failed to sync category for diary: $diaryId, Error: $e');
      }
    }

    // 下载资源文件
    diary.imageName = await _downloadFiles(diary.imageName, '${WebDavOptions.imagePath}/$diaryId', 'image');
    diary.audioName = await _downloadFiles(diary.audioName, '${WebDavOptions.audioPath}/$diaryId', 'audio');
    diary.videoName = await _downloadFiles(diary.videoName, '${WebDavOptions.videoPath}/$diaryId', 'video');
    // 下载视频缩略图
    await _downloadFiles(diary.videoName, '${WebDavOptions.videoPath}/$diaryId', 'thumbnail');
    return diary;
  }

  Future<List<String>> _downloadFiles(List<String> fileNames, String resourcePath, String type) async {
    final localFileNames = <String>[];

    for (final fileName in fileNames) {
      final serverFilePath =
          type == 'thumbnail' ? '$resourcePath/thumbnail-${fileName.substring(6, 42)}.jpeg' : '$resourcePath/$fileName';
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
