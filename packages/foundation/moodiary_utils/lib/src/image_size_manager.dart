import 'dart:io';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'lru.dart';

/// 图片宽高 / 宽高比的统一读取入口。从文件头元数据解析宽高（不解码整图），
/// 开销极低，故只挂内存 [LRUCache] 去重、不持久化。
class ImageSizeManager {
  ImageSizeManager._();

  static final ImageSizeManager _instance = ImageSizeManager._();

  factory ImageSizeManager() => _instance;

  final _aspectRatioCache = LRUCache<String, double>(maxSize: 1000);

  /// 宽高比（已按 EXIF 方向校正）。[imagePath] 兼作缓存 key；文件缺失/不支持时抛出。
  double getAspectRatio(String imagePath) {
    final cached = _aspectRatioCache.get(imagePath);
    if (cached != null) return cached;

    final (width, height) = getSize(imagePath);
    final aspectRatio = width / height;
    _aspectRatioCache.put(imagePath, aspectRatio);
    return aspectRatio;
  }

  /// 像素宽高（已按 EXIF 方向校正），返回 `(width, height)`。
  (int, int) getSize(String imagePath) {
    final size = ImageSizeGetter.getSizeResult(FileInput(File(imagePath))).size;
    // needRotate=EXIF 方向 90/270 度，宽高需互换。
    return size.needRotate
        ? (size.height, size.width)
        : (size.width, size.height);
  }

  void clear() => _aspectRatioCache.clear();
}
