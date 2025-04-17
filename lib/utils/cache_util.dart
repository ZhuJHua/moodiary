import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:moodiary/persistence/hive.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:path/path.dart';

class CacheUtil {
  static Future<List<String>?> getCacheList(
    String key,
    Future<List<String>?> Function() fetchData, {
    int maxAgeMillis = 900000,
  }) async {
    var cachedData = PrefUtil.getValue<List<String>>(key);
    // 检查缓存是否有效，如果无效则更新缓存
    if (cachedData == null || _isCacheExpired(cachedData, maxAgeMillis)) {
      await _updateCacheList(key, fetchData);

      cachedData = PrefUtil.getValue<List<String>>(key); // 获取更新后的缓存数据
    }
    return cachedData;
  }

  static bool _isCacheExpired(List<String> cachedData, int maxAgeMillis) {
    if (cachedData.length < 2) {
      return true; // 缓存数据格式不正确，视为过期
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
      await PrefUtil.setValue<List<String>>(
        key,
        newData..add(DateTime.now().millisecondsSinceEpoch.toString()),
      );
    }
  }
}

class ImageCacheUtil {
  ImageCacheUtil._();

  static final ImageCacheUtil _instance = ImageCacheUtil._();

  factory ImageCacheUtil() => _instance;

  late final _imageCacheBox = HiveUtil().imageCacheBox;

  late final _imageAspectBox = HiveUtil().imageAspectBox;

  Future<void> close() async {
    await _imageCacheBox.close();
  }

  Future<void> clearImageCache() async {
    await _imageCacheBox.clear();
    await _imageAspectBox.clear();
    await FileUtil.deleteDir(FileUtil.getRealPath('image_thumbnail', ''));
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
    final cachedImagePath = FileUtil.getRealPath(
      'image_thumbnail',
      cachedImageName,
    );
    final cachedImageFile = File(cachedImagePath);

    final bool isCached =
        (await _imageCacheBox.get(cachedImageName)) == true &&
        await cachedImageFile.exists();

    if (isCached) {
      //logger.i('Image cache hit at $cachedImageName');
      return cachedImagePath;
    }

    try {
      final compressedImage = await MediaUtil.compressImageData(
        imagePath: imagePath,
        size: baseMinSize,
        imageAspectRatio: imageAspectRatio,
      );

      if (compressedImage != null) {
        final newFile = await cachedImageFile.create(recursive: true);
        await newFile.writeAsBytes(compressedImage);
        await _imageCacheBox.put(cachedImageName, true);
        //logger.i('Image cached at $cachedImageName');
        return cachedImagePath;
      }
    } catch (e) {
      logger.d('Error compressing image: $e');
    }

    return imagePath;
  }

  Future<double> getImageAspectRatioWithCache({
    required String imagePath,
  }) async {
    final cachedAspectRatio = await (_imageAspectBox.get(basename(imagePath)));
    if (cachedAspectRatio != null) return cachedAspectRatio;
    try {
      final aspectRatio = await MediaUtil.getImageAspectRatio(
        FileImage(File(imagePath)),
      );
      await _imageAspectBox.put(basename(imagePath), aspectRatio);
      return aspectRatio;
    } catch (e) {
      logger.d('Error getting image aspect ratio: $e');
      rethrow;
    }
  }
}
