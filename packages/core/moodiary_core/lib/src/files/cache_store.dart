import 'dart:io';
import 'dart:math';

import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_core/src/app_logger.dart';
import 'package:moodiary_core/src/media/media_manager.dart';
import 'package:path/path.dart';

class CacheStore {
  /// 通过 KV 缓存带过期时间戳的 `List<String>`；[key] 须是 `MoodiaryKVs.xxx.name`。
  static Future<List<String>?> getCacheList(
    String key,
    Future<List<String>?> Function() fetchData, {
    int maxAgeMillis = 900000,
  }) async {
    final storage = IKVStorage.get();
    var cachedData = storage.get<List<String>>(key);
    if (cachedData == null || _isCacheExpired(cachedData, maxAgeMillis)) {
      await _updateCacheList(key, fetchData);
      cachedData = storage.get<List<String>>(key);
    }
    return cachedData;
  }

  static bool _isCacheExpired(List<String> cachedData, int maxAgeMillis) {
    if (cachedData.length < 2) {
      return true; // 格式不正确，视为过期
    }
    final int timestamp = int.parse(cachedData.last);
    return DateTime.now().millisecondsSinceEpoch - timestamp >= maxAgeMillis;
  }

  static Future<void> _updateCacheList(
    String key,
    Future<List<String>?> Function() fetchData,
  ) async {
    final newData = await fetchData();
    if (newData != null) {
      await IKVStorage.get().set<List<String>>(
        key,
        newData..add(DateTime.now().millisecondsSinceEpoch.toString()),
      );
    }
  }
}

class ImageCacheStore {
  ImageCacheStore._();

  static final ImageCacheStore _instance = ImageCacheStore._();

  factory ImageCacheStore() => _instance;

  Future<void> clearImageCache() async {
    await AppFiles.deleteDir(AppFiles.getRealPath('image_thumbnail', ''));
  }

  Future<String> getLocalImagePathWithCache({
    required String imagePath,
    required int imageWidth,
    required int imageHeight,
    required double imageAspectRatio,
  }) async {
    final int minSize = min(imageWidth, imageHeight);
    final int rangeStart = (minSize ~/ 100) * 100;
    final int rangeEnd = rangeStart + 100;
    final int baseMinSize = ((rangeStart + rangeEnd) / 2).round();

    final bool isWidthMin = imageWidth < imageHeight;
    final int standardWidth =
        isWidthMin ? baseMinSize : (baseMinSize * imageAspectRatio).round();
    final int standardHeight =
        isWidthMin ? (baseMinSize / imageAspectRatio).round() : baseMinSize;

    final cachedImageName =
        'resized_w${standardWidth}_h${standardHeight}_${basename(imagePath)}';
    final cachedImagePath = AppFiles.getRealPath(
      'image_thumbnail',
      cachedImageName,
    );
    final cachedImageFile = File(cachedImagePath);

    // 缩略图文件本身即缓存：存在即命中。
    if (await cachedImageFile.exists()) {
      return cachedImagePath;
    }

    try {
      // Rust 直接把压缩结果写到 cachedImagePath，不再经 Dart 堆中转。
      final ok = await MediaManager.compressImageToFile(
        imagePath: imagePath,
        outputPath: cachedImagePath,
        size: baseMinSize,
        imageAspectRatio: imageAspectRatio,
      );
      if (ok) {
        return cachedImagePath;
      }
    } catch (e) {
      logger.d('Error compressing image: $e');
    }

    return imagePath;
  }
}
