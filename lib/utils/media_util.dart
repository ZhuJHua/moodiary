import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:mood_diary/src/rust/api/compress.dart';
import 'package:mood_diary/utils/log_util.dart';
import 'package:mood_diary/utils/notice_util.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import '../common/values/media_type.dart';
import '../src/rust/api/constants.dart' as r_type;
import 'data/pref.dart';
import 'file_util.dart';

class MediaUtil {
  static final _picker = ImagePicker();

  static final _thumbnail = FcNativeVideoThumbnail();

  // 定义 MIME 类型到扩展名和压缩格式的映射
  static final _compressConfig = {
    'image/jpeg': ['.jpg', r_type.CompressFormat.jpeg],
    'image/png': ['.png', r_type.CompressFormat.png],
    'image/heic': ['.heic', CompressFormat.heic],
    'image/webp': ['.webp', r_type.CompressFormat.webP],
  };

  /// 保存图片
  /// 返回值：
  /// key：XFile 文件的临时目录
  /// value：实际的文件名
  static Future<Map<String, String>> saveImages({required List<XFile> imageFileList}) async {
    final imageNameMap = <String, String>{};
    await Future.wait(imageFileList.map((imageFile) async {
      if (basename(imageFile.path).startsWith('image-')) {
        imageNameMap[imageFile.path] = basename(imageFile.path);
        return;
      }
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/png'; // 默认使用 PNG
      final config = _compressConfig[mimeType] ?? ['.png', r_type.CompressFormat.png];
      final extension = config[0] as String;
      final format = config[1];
      final imageName = 'image-${const Uuid().v7()}$extension';
      final outputPath = FileUtil.getRealPath('image', imageName);
      await _compressImage(imageFile, outputPath, format);
      imageNameMap[imageFile.path] = imageName;
    }));

    return imageNameMap;
  }

  /// 保存音频
  /// 返回值：
  /// key：缓存目录的路径
  /// value：实际的文件名
  static Future<Map<String, String>> saveAudio(List<String> audioNames) async {
    final audioNameMap = <String, String>{};
    await Future.wait(audioNames.map((name) async {
      final file = File(FileUtil.getCachePath(name));
      final targetPath = FileUtil.getRealPath('audio', name);
      audioNameMap[file.path] = name;
      await file.copy(targetPath);
    }));
    return audioNameMap;
  }

  /// 保存视频
  /// 返回值：
  /// key：XFile 文件的临时目录
  /// value：实际的文件名
  static Future<Map<String, String>> saveVideo({required List<XFile> videoFileList}) async {
    Map<String, String> videoNameMap = {};

    await Future.wait(videoFileList.map((videoFile) async {
      if (basename(videoFile.path).startsWith('video-')) {
        videoNameMap[videoFile.path] = basename(videoFile.path);
        return;
      }
      // 生成文件名
      final uuid = const Uuid().v7();
      var videoName = 'video-$uuid.mp4';
      videoNameMap[videoFile.path] = videoName;
      // 保存视频文件
      await videoFile.saveTo(FileUtil.getRealPath('video', videoName));
      // 获取缩略图
      var tempThumbnailPath = FileUtil.getCachePath('${const Uuid().v7()}.jpeg');
      await _getVideoThumbnail(videoFile, tempThumbnailPath);
      // 压缩缩略图并保存
      var compressedPath = FileUtil.getRealPath('thumbnail', videoName);
      await _compressRust(
        XFile(tempThumbnailPath),
        compressedPath,
        r_type.CompressFormat.jpeg,
      );
      // 清理临时文件
      await File(tempThumbnailPath).delete();
    }));

    return videoNameMap;
  }

  static Future<void> regenerateMissingThumbnails() async {
    // 获取视频和缩略图路径的工具方法
    String getThumbnailPath(String videoName) => FileUtil.getRealPath('thumbnail', videoName);

    // 获取视频文件夹中的所有文件
    final videoDir = Directory(FileUtil.getRealPath('video', ''));
    if (!videoDir.existsSync()) return;

    // 遍历视频文件
    final videoFiles = videoDir.listSync().whereType<File>();
    for (final videoFile in videoFiles) {
      //如果是缩略图则跳过
      if (videoFile.path.contains('thumbnail')) continue;
      final videoName = basename(videoFile.path);
      final thumbnailPath = getThumbnailPath(videoName);
      // 检查是否存在缩略图
      if (!File(thumbnailPath).existsSync()) {
        LogUtil.printInfo("Thumbnail missing for $videoName. Regenerating...");

        try {
          // 生成临时缩略图路径
          final tempThumbnailPath = FileUtil.getCachePath('${const Uuid().v7()}.jpeg');

          // 获取视频缩略图
          await _getVideoThumbnail(XFile(videoFile.path), tempThumbnailPath);

          // 压缩并保存缩略图
          await _compressRust(
            XFile(tempThumbnailPath),
            thumbnailPath,
            r_type.CompressFormat.jpeg,
          );

          // 删除临时文件
          await File(tempThumbnailPath).delete();

          LogUtil.printInfo("Thumbnail regenerated for $videoName.");
        } catch (e) {
          LogUtil.printInfo("Failed to regenerate thumbnail for $videoName: $e");
        }
      } else {
        LogUtil.printInfo("Thumbnail exists for $videoName.");
      }
    }
  }

  //获取图片宽高
  static Future<Size> getImageSize(ImageProvider imageProvider) async {
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
  static Future<double> getImageAspectRatio(ImageProvider imageProvider) async {
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
  static Future<XFile?> pickPhoto(ImageSource imageSource) async {
    return await _picker.pickImage(
      source: imageSource,
    );
  }

  //获取单个视频
  static Future<XFile?> pickVideo(ImageSource imageSource) async {
    return await _picker.pickVideo(source: imageSource);
  }

  //异步获取图片颜色
  static Future<int> getColorScheme(ImageProvider imageProvider) async {
    var color = (await ColorScheme.fromImageProvider(provider: imageProvider)).primary;
    return ((color.a * 255).toInt() << 24) |
        ((color.r * 255).toInt() << 16) |
        ((color.g * 255).toInt() << 8) |
        (color.b * 255).toInt();
  }

  //获取多个图片
  static Future<List<XFile>> pickMultiPhoto(int? limit) async {
    return await _picker.pickMultiImage(limit: limit);
  }

  // 通用压缩逻辑
  static Future<void> _compressImage(
    XFile imageFile,
    String outputPath,
    dynamic format,
  ) async {
    if (format == CompressFormat.heic) {
      await _compressNative(imageFile, outputPath, format);
    } else {
      await _compressRust(imageFile, outputPath, format);
    }
  }

  static Future<void> _compressRust(XFile oldImage, String targetPath, r_type.CompressFormat format) async {
    var quality = switch (PrefUtil.getValue<int>('quality')) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    var oldPath = oldImage.path;
    var newImage =
        await ImageCompress.contain(filePath: oldPath, maxWidth: quality, maxHeight: quality, compressFormat: format);
    await File(targetPath).writeAsBytes(newImage);
  }

  //图片压缩
  static Future<void> _compressNative(XFile oldImage, String targetPath, CompressFormat format) async {
    if (Platform.isWindows) {
      oldImage.saveTo(targetPath);
      return;
    }
    var quality = PrefUtil.getValue<int>('quality');
    var height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    var newImage = await FlutterImageCompress.compressWithFile(
      oldImage.path,
      minHeight: height,
      minWidth: height,
      format: format,
    );
    if (newImage == null) {
      oldImage.saveTo(targetPath);
      return;
    }
    await File(targetPath).writeAsBytes(newImage);
  }

  //获取视频缩略图
  static Future<bool> _getVideoThumbnail(XFile xFile, destPath) async {
    var quality = PrefUtil.getValue<int>('quality');
    var height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    return await _thumbnail.getVideoThumbnail(
        srcFile: xFile.path, destFile: destPath, width: height, height: height, format: 'jpeg', quality: 90);
  }

  // 保存视频或者图片到相册
  static Future<void> saveToGallery({required String path, required MediaType type}) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) await Gal.requestAccess(toAlbum: true);
    try {
      if (type == MediaType.video) {
        await Gal.putVideo(path, album: 'Moodiary');
      } else {
        await Gal.putImage(path, album: 'Moodiary');
      }
      NoticeUtil.showToast('已保存到相册');
    } catch (e) {
      NoticeUtil.showToast('保存失败');
    }
  }
}
