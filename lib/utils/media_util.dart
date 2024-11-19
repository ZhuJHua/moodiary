import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/src/rust/api/compress.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:uuid/uuid.dart';

import '../src/rust/api/constants.dart' as r_type;

class MediaUtil {
  late final _picker = ImagePicker();

  late final _thumbnail = FcNativeVideoThumbnail();

  // 保存图片
  Future<List<String>> saveImages({required List<XFile> imageFileList}) async {
    List<String> nameList = [];
    for (var imageFile in imageFileList) {
      //生成新的名字
      var imageName = 'image-${const Uuid().v7()}.png';
      nameList.add(imageName);
      await _compressRust(imageFile, Utils().fileUtil.getRealPath('image', imageName), r_type.CompressFormat.png);
      //await _compressAndSaveImage(imageFile, Utils().fileUtil.getRealPath('image', imageName), CompressFormat.png);
    }
    return nameList;
  }

  // 保存录音
  Future<void> saveAudio(List<String> audioName) async {
    for (var name in audioName) {
      final file = File(Utils().fileUtil.getCachePath(name));
      await file.copy(Utils().fileUtil.getRealPath('audio', name));
    }
  }

  // 保存视频
  Future<List<String>> saveVideo(
      {required List<XFile> videoFileList, required List<XFile> videoThumbnailFileList}) async {
    List<String> nameList = [];
    for (var i = 0; i < videoFileList.length; ++i) {
      // 生成文件名
      final uuid = const Uuid().v7();
      var videoName = 'video-$uuid.mp4';
      nameList.add(videoName);
      await videoFileList[i].saveTo(Utils().fileUtil.getRealPath('video', videoName));
      await _compressRust(
          videoThumbnailFileList[i], Utils().fileUtil.getRealPath('thumbnail', videoName), r_type.CompressFormat.jpeg);
      // await _compressAndSaveImage(
      //     videoThumbnailFileList[i], Utils().fileUtil.getRealPath('thumbnail', videoName), CompressFormat.jpeg);
    }
    return nameList;
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
  Future<List<XFile>> pickMultiPhoto(int? limit) async {
    return await _picker.pickMultiImage(limit: limit);
  }

  Future<void> _compressRust(XFile oldImage, String targetPath, r_type.CompressFormat format) async {
    var quality = switch (Utils().prefUtil.getValue<int>('quality')) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    var newImage = await ImageCompress.contain(
        filePath: oldImage.path, maxWidth: quality, maxHeight: quality, compressFormat: format);
    await File(targetPath).writeAsBytes(newImage);
  }

  // //图片压缩
  // Future<XFile?> _compressAndSaveImage(XFile oldImage, String targetPath, CompressFormat format) async {
  //   // 如果是已经压缩过的
  //   if (oldImage.path == targetPath) {
  //     return oldImage;
  //   }
  //   if (Platform.isWindows) {
  //     oldImage.saveTo(targetPath);
  //     return oldImage;
  //   }
  //   var quality = Utils().prefUtil.getValue<int>('quality');
  //   var height = switch (quality) {
  //     0 => 720,
  //     1 => 1080,
  //     2 => 1440,
  //     _ => 1080,
  //   };
  //
  //   return await FlutterImageCompress.compressAndGetFile(
  //     oldImage.path,
  //     targetPath,
  //     minHeight: height,
  //     minWidth: height,
  //     format: format,
  //   );
  // }

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
