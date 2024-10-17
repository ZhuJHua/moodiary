import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/utils/utils.dart';

class MediaUtil {
  late final _picker = ImagePicker();

  late final _thumbnail = FcNativeVideoThumbnail();

  // 保存图片
  Future<void> saveImages(Map<String, XFile> imageMap) async {
    for (var entry in imageMap.entries) {
      await _compressAndSaveImage(entry.value, Utils().fileUtil.getRealPath('image', entry.key), CompressFormat.webp);
    }
  }

  // 保存录音
  Future<void> saveAudio(List<String> audioName) async {
    for (var name in audioName) {
      final file = File(Utils().fileUtil.getCachePath(name));
      await file.copy(Utils().fileUtil.getRealPath('audio', name));
    }
  }

  // 保存视频
  Future<void> saveVideo(Map<String, XFile> videoMap, Map<String, XFile> thumbnailMap) async {
    for (var entry in videoMap.entries) {
      await entry.value.saveTo(Utils().fileUtil.getRealPath('video', entry.key));
    }

    for (var entry in thumbnailMap.entries) {
      await _compressAndSaveImage(entry.value, Utils().fileUtil.getRealPath('video', entry.key), CompressFormat.jpeg);
    }
  }

  //获取图片宽高
  Future<Size> getImageSize(ImageProvider imageProvider) async {
    final Completer<Size> completer = Completer<Size>();
    final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          final Size size = Size(info.image.width.toDouble(), info.image.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }

  //获取图片宽高比例
  Future<double> getImageAspectRatio(ImageProvider imageProvider) async {
    final Completer<double> completer = Completer<double>();
    final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          final double aspectRatio =
              double.parse((info.image.width.toDouble() / info.image.height.toDouble()).toStringAsPrecision(2));
          completer.complete(aspectRatio);
        },
      ),
    );
    return completer.future;
  }

  //获取单个图片，拍照或者相册
  Future<XFile?> pickPhoto(ImageSource imageSource) async {
    return await _picker.pickImage(
      source: imageSource,
    );
  }

  //获取单个视频
  Future<XFile?> pickVideo(ImageSource imageSource) async {
    return await _picker.pickVideo(source: imageSource);
  }

  //异步获取图片颜色
  Future<int> getColorScheme(ImageProvider imageProvider) async {
    var color = (await ColorScheme.fromImageProvider(provider: imageProvider)).primary;
    return ((color.a * 255).toInt() << 24) |
        ((color.r * 255).toInt() << 16) |
        ((color.g * 255).toInt() << 8) |
        (color.b * 255).toInt();
  }

  //获取多个图片
  Future<List<XFile>> pickMultiPhoto(int limit) async {
    return await _picker.pickMultiImage(limit: limit);
  }

  //图片压缩
  Future<XFile?> _compressAndSaveImage(XFile oldImage, String targetPath, CompressFormat format) async {
    // 如果是已经压缩过的
    if (oldImage.path == targetPath) {
      return oldImage;
    }
    if (Platform.isWindows) {
      return oldImage;
    }
    var quality = Utils().prefUtil.getValue<int>('quality');
    var height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };

    return await FlutterImageCompress.compressAndGetFile(
      oldImage.path,
      targetPath,
      minHeight: height,
      minWidth: height,
      format: format,
    );
  }

  //获取视频缩略图
  Future<bool> getVideoThumbnail(XFile xFile, destPath) async {
    var quality = Utils().prefUtil.getValue<int>('quality');
    var height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    return await _thumbnail.getVideoThumbnail(
        srcFile: xFile.path, destFile: destPath, width: height, height: height, format: 'jpeg', quality: 90);
  }
}
