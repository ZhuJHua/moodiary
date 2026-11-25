import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart' as ip;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:photo_manager/photo_manager.dart';

abstract final class MoodiaryCamera {
  static final ip.ImagePicker _picker = ip.ImagePicker();

  static Future<AssetEntity?> takePhoto() => _capture(video: false);

  static Future<AssetEntity?> recordVideo() => _capture(video: true);

  static Future<AssetEntity?> _capture({required bool video}) async {
    try {
      final shot = video
          ? await _picker.pickVideo(source: ip.ImageSource.camera)
          // imageQuality 不能传：Android 会重新编码并丢失部分 EXIF（含方向）
          : await _picker.pickImage(source: ip.ImageSource.camera);
      if (shot == null) return null;
      return await _saveToGallery(shot.path, video: video);
    } catch (e, s) {
      logger.d('camera capture failed: $e\n$s');
      return null;
    }
  }

  // Android 低内存会回收 MainActivity，拍摄结果需靠这个方法事后找回，不调用会静默丢照片
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
