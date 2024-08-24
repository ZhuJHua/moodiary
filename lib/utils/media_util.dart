import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/utils/utils.dart';

class MediaUtil {
  late final _picker = ImagePicker();

  //保存图片
  Future<void> saveImages(Map<String, Uint8List> imageMap) async {
    await Future.forEach(imageMap.entries, (entry) async {
      final file = File(Utils().fileUtil.getRealPath('image', entry.key));
      await file.writeAsBytes(entry.value, flush: true);
    });
  }

  //保存录音
  Future<void> savaAudio(List<String> audioName) async {
    await Future.forEach(audioName, (name) async {
      final file = File(Utils().fileUtil.getCachePath(name));
      await file.copy(Utils().fileUtil.getRealPath('audio', name));
    });
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
    //await callPhotoPicker();
    return await _picker.pickImage(
      source: imageSource,
    );
  }

  //获取单个视频
  Future<XFile?> pickVideo(ImageSource imageSource) async {
    return await _picker.pickVideo(source: imageSource);
  }

  //异步获取图片颜色
  Future<Color> getColorScheme(ImageProvider imageProvider) async {
    return (await ColorScheme.fromImageProvider(provider: imageProvider)).primary;
  }

  //获取多个图片
  Future<List<XFile>> pickMultiPhoto(int limit) async {
    //await callPhotoPicker();
    return await _picker.pickMultiImage(limit: limit);
  }

  //图片压缩
  Future<Uint8List> compressImage(oldImage) async {
    if (Platform.isWindows) {
      return oldImage;
    }
    var height = switch (Utils().prefUtil.getValue<int>('quality')) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    return await FlutterImageCompress.compressWithList(
      oldImage,
      minHeight: height,
      minWidth: height,
      format: CompressFormat.webp,
    );
  }
}
