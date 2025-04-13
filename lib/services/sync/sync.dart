import 'dart:async';

import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/sync/sync.dart';
import 'package:moodiary/common/values/sync_status.dart';
import 'package:moodiary/services/sync/impl/webdav_impl.dart';

/// 同步服务的抽象基类
abstract class SyncService {
  /// 是否有配置
  bool get hasConfig;

  /// 连通性
  /// 返回值为 [ConnectivityStatus]
  /// 这是一个响应式变量，可以通过 [Obx] 进行监听
  ConnectivityStatus get rxConnectivity;

  /// 初始化方法
  Future<void> init();

  /// 连通性检查
  Future<void> checkConnectivity();

  /// 同步日记
  /// 这个方法会自动进行增量同步
  Future<SyncResult> syncDiary({
    required List<Diary> diaries,
    VoidCallback? onUpload,
    VoidCallback? onDownload,
    VoidCallback? onComplete,
    Function(int, int)? onProgress,
  });

  /// 上传日记
  /// 可选参数为加密
  /// 返回值 [SyncResult] 为同步结果
  /// [onStart] 为开始回调
  /// [onComplete] 为完成回调
  /// [onProgress] 为进度回调
  Future<SyncResult> uploadDiary({
    required Diary diary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int, int)? onProgress,
  });

  /// 更新日记
  /// 可选参数为加密
  /// 返回值 [SyncResult] 为同步结果
  /// [onStart] 为开始回调
  /// [onComplete] 为完成回调
  /// [onProgress] 为进度回调
  Future<SyncResult> updateDiary({
    required Diary oldDiary,
    required Diary newDiary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int, int)? onProgress,
  });

  /// 下载日记
  /// 返回值 [SyncResult] 为同步结果
  /// [onStart] 为开始回调
  /// [onComplete] 为完成回调
  /// [onProgress] 为进度回调
  Future<SyncResult> downloadDiary({
    required String diaryId,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int, int)? onProgress,
  });

  /// 删除日记
  /// 返回值 [SyncResult] 为同步结果
  /// [onStart] 为开始回调
  /// [onComplete] 为完成回调
  /// [onProgress] 为进度回调
  Future<SyncResult> deleteDiary({
    required Diary diary,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(int, int)? onProgress,
  });

  /// 获取服务器同步数据
  /// 文件名为 [sync.json]
  /// 返回值  [SyncResult] 为同步结果
  /// [Map] 为同步数据
  Future<SyncResult<Map<String, String>>> fetchServerSyncData();

  /// 更新服务器同步数据
  Future<SyncResult> updateServerSyncData(Map<String, String> syncData);
}

/// 同步服务的具体实现
/// 通过 [WebdavSyncServiceImpl] 进行同步
class WebdavSyncService extends GetxService {
  late final SyncService _webdavSyncService;

  Future<void> init({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _webdavSyncService = WebdavSyncServiceImpl(
      url: baseUrl,
      username: username,
      password: password,
    );
    await _webdavSyncService.init();
  }

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }
}

// /// 通过 MinIO 对象存储进行同步
// /// 通过 [MinioSyncServiceImpl] 进行同步
// class MinioSyncService extends GetxService {
//   late final SyncService _minioSyncService;
//
//   Future<void> init({
//     required String endPoint,
//     required String accessKey,
//     required String secretKey,
//     required String bucketName,
//   }) async {
//     _minioSyncService = MinioSyncServiceImpl(
//       endPoint: endPoint,
//       accessKey: accessKey,
//       secretKey: secretKey,
//       bucketName: bucketName,
//     );
//     await _minioSyncService.init();
//   }
// }
