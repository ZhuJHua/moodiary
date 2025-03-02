import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/sync/sync.dart';
import 'package:moodiary/common/values/sync_status.dart';
import 'package:moodiary/common/values/webdav.dart';
import 'package:moodiary/services/sync/sync.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class WebdavSyncServiceImpl implements SyncService {
  final String url;
  final String username;
  final String password;

  late final webdav.Client _client;
  final Rx<ConnectivityStatus> _connectivity =
      ConnectivityStatus.connecting.obs;

  bool get _isConnected => _connectivity.value == ConnectivityStatus.connected;
  late Map<String, String> _syncStatus;
  Timer? _connectivityTimer;

  WebdavSyncServiceImpl({
    required this.url,
    required this.username,
    required this.password,
  });

  @override
  Future<void> init() async {
    _client = webdav.newClient(
      url,
      user: username,
      password: password,
      debug: false,
    );
    await checkConnectivity();
    startPolling();
  }

  void startPolling({Duration interval = const Duration(minutes: 1)}) {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(interval, (timer) async {
      await checkConnectivity();
    });
  }

  void stopPolling() {
    _connectivityTimer?.cancel();
  }

  @override
  Future<void> checkConnectivity() async {
    _connectivity.value = ConnectivityStatus.connecting;
    try {
      await _client.ping().timeout(const Duration(seconds: 3));
      _connectivity.value = ConnectivityStatus.connected;
    } catch (e) {
      LogUtil.printError("WebDAV Error Check Connectivity", error: e);
      _connectivity.value = ConnectivityStatus.disconnected;
    }
  }

  Future<void> initDir() async {
    if (!_isConnected) return;

    final paths = [
      WebDavOptions.imagePath,
      WebDavOptions.videoPath,
      WebDavOptions.audioPath,
      WebDavOptions.diaryPath,
      WebDavOptions.categoryPath,
    ];

    for (final path in paths) {
      try {
        await _client.mkdirAll(path);
      } catch (e) {
        LogUtil.printError("创建目录失败: $path", error: e);
      }
    }

    try {
      await _client.read(WebDavOptions.syncFlagPath);
    } catch (_) {
      await _client.write(
        WebDavOptions.syncFlagPath,
        utf8.encode(jsonEncode({})),
      );
    }
  }

  @override
  Future<SyncResult<Map<String, String>>> fetchServerSyncData() async {
    if (!_isConnected) return SyncResult(status: SyncStatus.invalid);

    try {
      final response = await _client.read(WebDavOptions.syncFlagPath);
      if (response.isNotEmpty) {
        return SyncResult(
          status: SyncStatus.success,
          data: jsonDecode(utf8.decode(response)) as Map<String, String>,
        );
      }
    } catch (e) {
      LogUtil.printError("获取服务器同步数据失败", error: e);
    }
    return SyncResult(status: SyncStatus.failure);
  }

  @override
  Future<SyncResult<bool>> updateServerSyncData(
    Map<String, String> syncData,
  ) async {
    if (!_isConnected) return SyncResult(status: SyncStatus.invalid);

    try {
      await _client.write(
        WebDavOptions.syncFlagPath,
        utf8.encode(jsonEncode(syncData)),
      );
      return SyncResult(status: SyncStatus.success, data: true);
    } catch (e) {
      LogUtil.printError("更新服务器同步数据失败", error: e);
      return SyncResult(status: SyncStatus.failure);
    }
  }

  @override
  Future<SyncResult> deleteDiary({
    required Diary diary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int p1, int p2)? onProgress,
  }) async {
    if (!_isConnected) return SyncResult(status: SyncStatus.invalid);

    if (!_syncStatus.containsKey(diary.id)) {
      return SyncResult(status: SyncStatus.success);
    }

    _syncStatus[diary.id] = 'delete';
    await updateServerSyncData(_syncStatus);

    // 批量删除文件
    try {
      await Future.wait([
        _deleteFile('${WebDavOptions.diaryPath}/${diary.id}.json'),
        _deleteFile('${WebDavOptions.diaryPath}/${diary.id}.bin'),
        _deleteFiles(
          diary.imageName,
          '${WebDavOptions.imagePath}/${diary.id}',
          'image',
        ),
        _deleteFiles(
          diary.audioName,
          '${WebDavOptions.audioPath}/${diary.id}',
          'audio',
        ),
        _deleteFiles(
          diary.videoName,
          '${WebDavOptions.videoPath}/${diary.id}',
          'video',
        ),
        _deleteFiles(
          diary.videoName
              .map(
                (videoName) => 'thumbnail-${videoName.substring(6, 42)}.jpeg',
              )
              .toList(),
          '${WebDavOptions.videoPath}/${diary.id}',
          'thumbnail',
        ),
        _deleteFile('${WebDavOptions.imagePath}/${diary.id}'),
        _deleteFile('${WebDavOptions.audioPath}/${diary.id}'),
        _deleteFile('${WebDavOptions.videoPath}/${diary.id}'),
      ]);
    } catch (e) {
      LogUtil.printError("删除日记失败", error: e);
      return SyncResult(status: SyncStatus.failure);
    }

    return SyncResult(status: SyncStatus.success);
  }

  Future<void> _deleteFile(String path) async {
    try {
      await _client.remove(path);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _deleteFiles(
    List<String> fileNames,
    String resourcePath,
    String type,
  ) async {
    for (final fileName in fileNames) {
      await _deleteFile('$resourcePath/$fileName');
    }
  }

  @override
  Future<SyncResult> downloadDiary({
    required String diaryId,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int p1, int p2)? onProgress,
  }) async {
    if (!_isConnected) return SyncResult(status: SyncStatus.invalid);
    debugPrint("下载日记 $diaryId (未实现)");
    return SyncResult(status: SyncStatus.failure);
  }

  @override
  Future<SyncResult> uploadDiary({
    required Diary diary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int p1, int p2)? onProgress,
  }) async {
    if (!_isConnected) return SyncResult(status: SyncStatus.invalid);
    debugPrint("上传日记 ${diary.id} (未实现)");
    return SyncResult(status: SyncStatus.failure);
  }

  void dispose() {
    stopPolling();
  }

  @override
  Future<SyncResult> updateDiary({
    required Diary oldDiary,
    required Diary newDiary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int p1, int p2)? onProgress,
  }) {
    // TODO: implement updateDiary
    throw UnimplementedError();
  }

  @override
  Future<SyncResult> syncDiary({
    required List<Diary> diaries,
    VoidCallback? onUpload,
    VoidCallback? onDownload,
    VoidCallback? onComplete,
    Function(int p1, int p2)? onProgress,
  }) async {
    throw UnimplementedError();
  }

  @override
  // TODO: implement hasConfig
  bool get hasConfig => throw UnimplementedError();

  @override
  // TODO: implement connectivity
  ConnectivityStatus get rxConnectivity => _connectivity.value;
}
