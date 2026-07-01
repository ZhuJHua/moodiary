import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_core/src/utils/file_util.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/src/utils/log_util.dart';
import 'package:moodiary_core/src/utils/notice_util.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:moodiary_core/src/values/media_type.dart';
import 'package:path/path.dart';

enum ImageFormat {
  jpeg(extension: '.jpg'),
  png(extension: '.png'),
  heic(extension: '.heic'),
  webp(extension: '.webp');

  final String extension;

  const ImageFormat({required this.extension});

  static ImageFormat getImageFormat(String imagePath) {
    final mimeType = lookupMimeType(imagePath);
    if (mimeType == null) return ImageFormat.png;
    switch (mimeType) {
      case 'image/jpeg':
        return ImageFormat.jpeg;
      case 'image/png':
        return ImageFormat.png;
      case 'image/heic':
        return ImageFormat.heic;
      case 'image/webp':
        return ImageFormat.webp;
      default:
        return ImageFormat.png;
    }
  }
}

class MediaUtil {
  static final _picker = ImagePicker();

  static final _thumbnail = FcNativeVideoThumbnail();

  /// 返回 map：key=XFile 临时路径，value=实际文件名
  static Future<Map<String, String>> saveImages({
    required List<XFile> imageFileList,
  }) async {
    final imageNameMap = <String, String>{};
    await Future.wait(
      imageFileList.map((imageFile) async {
        if (basename(imageFile.path).startsWith('image-')) {
          imageNameMap[imageFile.path] = basename(imageFile.path);
          return;
        }
        var workingFile = imageFile;
        var imageFormat = ImageFormat.getImageFormat(imageFile.path);
        // HEIC 在 Rust 侧无法解码，先转 JPEG 再按 JPEG 压缩存储。
        String? heicTempPath;
        if (imageFormat == ImageFormat.heic) {
          heicTempPath = await _convertHeicToJpeg(imageFile.path);
          if (heicTempPath != null) {
            workingFile = XFile(heicTempPath);
            imageFormat = ImageFormat.jpeg;
          }
        }
        try {
          final imageName = 'image-${uuidV7()}${imageFormat.extension}';
          final outputPath = FileUtil.getRealPath('image', imageName);
          await compressAndSaveImage(workingFile, outputPath, imageFormat);
          imageNameMap[imageFile.path] = imageName;
        } finally {
          if (heicTempPath != null) {
            try {
              await File(heicTempPath).delete();
            } catch (_) {}
          }
        }
      }),
    );

    return imageNameMap;
  }

  /// 返回 map：key=缓存路径，value=实际文件名
  static Future<Map<String, String>> saveAudio(List<String> audioNames) async {
    final audioNameMap = <String, String>{};
    await Future.wait(
      audioNames.map((name) async {
        final file = File(FileUtil.getCachePath(name));
        final targetPath = FileUtil.getRealPath('audio', name);
        audioNameMap[file.path] = name;
        await file.copy(targetPath);
      }),
    );
    return audioNameMap;
  }

  /// 返回 map：key=XFile 临时路径，value=实际文件名
  static Future<Map<String, String>> saveVideo({
    required List<XFile> videoFileList,
  }) async {
    final Map<String, String> videoNameMap = {};

    await Future.wait(
      videoFileList.map((videoFile) async {
        if (basename(videoFile.path).startsWith('video-')) {
          videoNameMap[videoFile.path] = basename(videoFile.path);
          return;
        }
        final uuid = uuidV7();
        final videoName = 'video-$uuid.mp4';
        videoNameMap[videoFile.path] = videoName;
        await videoFile.saveTo(FileUtil.getRealPath('video', videoName));
        final tempThumbnailPath = FileUtil.getRealPath('thumbnail', videoName);
        await _getVideoThumbnail(videoFile, tempThumbnailPath);
      }),
    );

    return videoNameMap;
  }

  static Future<void> regenerateMissingThumbnails() async {
    String getThumbnailPath(String videoName) =>
        FileUtil.getRealPath('thumbnail', videoName);

    final videoDir = Directory(FileUtil.getRealPath('video', ''));
    if (!videoDir.existsSync()) return;

    final videoFiles = videoDir.listSync().whereType<File>();
    for (final videoFile in videoFiles) {
      if (videoFile.path.contains('thumbnail')) continue;
      final videoName = basename(videoFile.path);
      final thumbnailPath = getThumbnailPath(videoName);
      if (!File(thumbnailPath).existsSync()) {
        logger.d("Thumbnail missing for $videoName. Regenerating...");

        try {
          await _getVideoThumbnail(XFile(videoFile.path), thumbnailPath);

          logger.d("Thumbnail regenerated for $videoName.");
        } catch (e) {
          logger.d("Failed to regenerate thumbnail for $videoName: $e");
        }
      } else {
        logger.d("Thumbnail exists for $videoName.");
      }
    }
  }

  static Future<Size> getImageSize(ImageProvider imageProvider) async {
    final Completer<Size> completer = Completer<Size>();
    final ImageStream stream = imageProvider.resolve(
      const ImageConfiguration(),
    );
    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final Size size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        completer.complete(size);
      }),
    );
    return completer.future;
  }

  static Future<XFile?> pickPhoto(ImageSource imageSource) async {
    return await _picker.pickImage(source: imageSource);
  }

  static Future<XFile?> pickVideo(ImageSource imageSource) async {
    return await _picker.pickVideo(source: imageSource);
  }

  static Future<int> getColorScheme(ImageProvider imageProvider) async {
    final color = (await ColorScheme.fromImageProvider(
      provider: imageProvider,
    )).primary;
    return ((color.a * 255).toInt() << 24) |
        ((color.r * 255).toInt() << 16) |
        ((color.g * 255).toInt() << 8) |
        (color.b * 255).toInt();
  }

  static Future<List<XFile>> pickMultiPhoto(int? limit) async {
    return await _picker.pickMultiImage(limit: limit);
  }

  /// Rust 解码+缩放后直接写 outputPath，像素不经 FFI 拷贝到 Dart 堆。
  /// 返回 true=已写入；false=失败，调用方自行兜底。
  static Future<bool> compressImageToFile({
    required String imagePath,
    required String outputPath,
    ImageFormat? imageFormat,
    int? size,
    double? imageAspectRatio,
  }) async {
    final imageFormat_ = imageFormat ?? ImageFormat.getImageFormat(imagePath);
    return switch (imageFormat_) {
      ImageFormat.jpeg => _compressRustToFile(
        imagePath,
        outputPath,
        rust.CompressFormat.jpeg,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.png => _compressRustToFile(
        imagePath,
        outputPath,
        rust.CompressFormat.png,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.heic => _compressHeicToFile(
        imagePath,
        outputPath,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.webp => _compressRustToFile(
        imagePath,
        outputPath,
        rust.CompressFormat.webP,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
    };
  }

  static Future<void> compressAndSaveImage(
    XFile imageFile,
    String outputPath,
    ImageFormat imageFormat,
  ) async {
    if (MoodiaryKVs.quality.get() == 3) {
      await imageFile.saveTo(outputPath);
      return;
    }
    final ok = await compressImageToFile(
      imagePath: imageFile.path,
      outputPath: outputPath,
      imageFormat: imageFormat,
    );
    if (!ok) {
      await imageFile.saveTo(outputPath);
    }
  }

  /// HEIC 不能被 Rust 直接解码，先转 JPEG 临时文件再压缩，最后清理。
  static Future<bool> _compressHeicToFile(
    String imagePath,
    String outputPath, {
    int? size,
    double? imageAspectRatio,
  }) async {
    final tempPath = await _convertHeicToJpeg(imagePath);
    if (tempPath == null) return false;
    try {
      return await _compressRustToFile(
        tempPath,
        outputPath,
        rust.CompressFormat.jpeg,
        size: size,
        imageAspectRatio: imageAspectRatio,
      );
    } finally {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  /// 转 JPEG 临时文件，调用方负责清理。
  static Future<String?> _convertHeicToJpeg(String heicPath) async {
    try {
      final tempJpegPath =
          '${Directory.systemTemp.path}/heic_${uuidV7()}.jpg';
      return await HeifConverter.convert(
        heicPath,
        output: tempJpegPath,
        format: 'jpg',
      );
    } catch (e) {
      logger.d('HEIC -> JPEG conversion failed: $e');
      return null;
    }
  }

  static Future<bool> _compressRustToFile(
    String imagePath,
    String outputPath,
    rust.CompressFormat format, {
    int? size,
    double? imageAspectRatio,
  }) async {
    final imageSize =
        size ??
        switch (MoodiaryKVs.quality.get()) {
          0 => 720,
          1 => 1080,
          2 => 1440,
          _ => 1080,
        };
    try {
      final imageAspect =
          imageAspectRatio ?? ImageSizeManager().getAspectRatio(imagePath);

      // 横图：高度为 size，宽度按比例缩放；竖图反之。
      final width = imageAspect < 1.0
          ? imageSize
          : (imageSize * imageAspect).ceil();
      final height = imageAspect >= 1.0
          ? imageSize
          : (imageSize / imageAspect).ceil();
      await rust.ImageCompressor.containToFile(
        filePath: imagePath,
        outputPath: outputPath,
        targetHeight: height,
        targetWidth: width,
        compressFormat: format,
      );
      return true;
    } catch (e) {
      logger.d('Image compression failed: $e');
      return false;
    }
  }

  static Future<bool> _getVideoThumbnail(XFile xFile, destPath) async {
    final quality = MoodiaryKVs.quality.get();
    final height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    return await _thumbnail.saveThumbnailToFile(
      srcFile: xFile.path,
      destFile: destPath,
      width: height,
      height: height,
      format: 'jpeg',
      quality: 90,
    );
  }

  static Future<void> saveToGallery({
    required String path,
    required MediaType type,
  }) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) await Gal.requestAccess(toAlbum: true);
    try {
      if (type == MediaType.video) {
        await Gal.putVideo(path, album: 'Moodiary');
      } else {
        await Gal.putImage(path, album: 'Moodiary');
      }
      toast.success(message: '已保存到相册');
    } catch (e) {
      toast.error(message: '保存失败');
    }
  }

  static DateTime? extractDateFromUUID(String uuid) {
    final timestampHex = uuid.replaceAll('-', '').substring(0, 12);
    final timestampInt = int.tryParse(timestampHex, radix: 16);
    if (timestampInt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestampInt);
  }

  /// 根据日期分组文件
  static Map<DateTime, List<String>> groupImageFileByDate(
    List<String> filePaths,
  ) {
    final Map<DateTime, List<String>> groupedMap = {};
    for (final image in filePaths) {
      final uuid = image.split('image-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

        groupedMap.putIfAbsent(dateOnly, () => []).add(image);
      }
    }
    groupedMap.forEach((key, value) {
      value.sort(
        (a, b) =>
            basename(b).split('.')[0].compareTo(basename(a).split('.')[0]),
      );
    });
    final sortedEntries = groupedMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  static Map<DateTime, List<String>> groupVideoFileByDate(
    List<String> filePaths,
  ) {
    final Map<DateTime, List<String>> groupedMap = {};
    for (final video in filePaths) {
      if (!basename(video).startsWith('video-')) continue;
      final uuid = video.split('video-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
        groupedMap.putIfAbsent(dateOnly, () => []).add(video);
      }
    }
    groupedMap.forEach((key, value) {
      value.sort(
        (a, b) =>
            basename(b).split('.')[0].compareTo(basename(a).split('.')[0]),
      );
    });
    final sortedEntries = groupedMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  static Map<DateTime, List<String>> groupAudioFileByDate(
    List<String> filePaths,
  ) {
    final Map<DateTime, List<String>> groupedMap = {};
    for (final audio in filePaths) {
      final uuid = audio.split('audio-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
        groupedMap.putIfAbsent(dateOnly, () => []).add(audio);
      }
    }
    groupedMap.forEach((key, value) {
      value.sort(
        (a, b) =>
            basename(b).split('.')[0].compareTo(basename(a).split('.')[0]),
      );
    });
    final sortedEntries = groupedMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }
}
