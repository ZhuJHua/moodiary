import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart' as ip;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:photo_manager/photo_manager.dart';

/// 拍照 / 录像 —— 直接拉起**系统相机界面**，不自绘取景。
///
/// 换来的是：取景、对焦、曝光、闪光灯、变焦、方向、录制状态机全部归系统，
/// 我们一行都不用维护（自建那版光这些就是 700 行，而且方向那条在 Android 上
/// 还得自己接加速度计）。代价是拍摄界面长成系统的样子、且**成片默认不落相册**。
abstract final class MoodiaryCamera {
  static final ip.ImagePicker _picker = ip.ImagePicker();

  /// 拍照。返回**系统相册里**那条资源。
  static Future<AssetEntity?> takePhoto() => _capture(video: false);

  /// 录像。返回**系统相册里**那条资源。
  static Future<AssetEntity?> recordVideo() => _capture(video: true);

  static Future<AssetEntity?> _capture({required bool video}) async {
    try {
      final shot = video
          // 不传 maxDuration：录像一直没有时长上限，这是既有行为。
          ? await _picker.pickVideo(source: ip.ImageSource.camera)
          // **imageQuality 不能传**：传了 Android 会重新编码，顺带丢掉一部分
          // EXIF（含方向）。相机场景只要原样拿回来。
          : await _picker.pickImage(source: ip.ImageSource.camera);
      if (shot == null) return null;
      return await _saveToGallery(shot.path, video: video);
    } catch (e, s) {
      logger.d('camera capture failed: $e\n$s');
      return null;
    }
  }

  /// Android 的 MainActivity 在低内存下会被回收，那次拍摄的结果只能事后捞。
  ///
  /// **不接这个就是静默丢照片**（而且发起那次的 Future 永远不会完成）。在选择器
  /// 打开时调一次，捞到就当成刚拍完的那张。
  static Future<AssetEntity?> retrieveLost() async {
    if (!Platform.isAndroid) return null;
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (lost.isEmpty || file == null) return null;
      return await _saveToGallery(
        file.path,
        video: lost.type == ip.RetrieveType.video,
      );
    } catch (e) {
      logger.d('retrieveLostData failed: $e');
      return null;
    }
  }

  static String _titleOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// **image_picker 两端都不把成片写进系统相册**，也没有任何开关：Android 的
  /// `EXTRA_OUTPUT` 指向应用私有 cacheDir 的 FileProvider URI（全源码零 MediaStore
  /// 写入），iOS 只写 `NSTemporaryDirectory()`。而「拍完原片还在你自己相册里」是
  /// 既有契约，所以这一步得自己补。
  ///
  /// 顺带把临时文件删掉 —— 那份没人清理，不删就是每拍一次多留一份。
  static Future<AssetEntity?> _saveToGallery(
    String path, {
    required bool video,
  }) async {
    try {
      return video
          ? await PhotoManager.editor.saveVideo(
              File(path),
              title: _titleOf(path),
            )
          : await PhotoManager.editor.saveImageWithPath(
              path,
              title: _titleOf(path),
            );
    } catch (e) {
      logger.d('save capture to gallery failed: $e');
      return null;
    } finally {
      unawaited(File(path).delete().catchError((_) => File(path)));
    }
  }
}
