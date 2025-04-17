import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mime/mime.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/src/rust/api/compress.dart';
import 'package:moodiary/src/rust/api/constants.dart' as r_type;
import 'package:moodiary/utils/cache_util.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/lru.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

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

  static final _imageAspectRatioCache = AsyncLRUCache<String, double>(
    maxSize: 1000,
  );

  static void useAndroidImagePicker() {
    final ImagePickerPlatform imagePickerImplementation =
        ImagePickerPlatform.instance;
    if (imagePickerImplementation is ImagePickerAndroid) {
      imagePickerImplementation.useAndroidPhotoPicker = true;
    }
  }

  /// 保存图片
  /// 返回值：
  /// key：XFile 文件的临时目录
  /// value：实际的文件名
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
        final imageFormat = ImageFormat.getImageFormat(imageFile.path);
        final imageName = 'image-${const Uuid().v7()}${imageFormat.extension}';
        final outputPath = FileUtil.getRealPath('image', imageName);
        await compressAndSaveImage(imageFile, outputPath, imageFormat);
        imageNameMap[imageFile.path] = imageName;
      }),
    );

    return imageNameMap;
  }

  /// 保存音频
  /// 返回值：
  /// key：缓存目录的路径
  /// value：实际的文件名
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

  /// 保存视频
  /// 返回值：
  /// key：XFile 文件的临时目录
  /// value：实际的文件名
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
        // 生成文件名
        final uuid = const Uuid().v7();
        final videoName = 'video-$uuid.mp4';
        videoNameMap[videoFile.path] = videoName;
        // 保存视频文件
        await videoFile.saveTo(FileUtil.getRealPath('video', videoName));
        // 获取缩略图
        final tempThumbnailPath = FileUtil.getRealPath('thumbnail', videoName);
        await _getVideoThumbnail(videoFile, tempThumbnailPath);
      }),
    );

    return videoNameMap;
  }

  static Future<void> regenerateMissingThumbnails() async {
    // 获取视频和缩略图路径的工具方法
    String getThumbnailPath(String videoName) =>
        FileUtil.getRealPath('thumbnail', videoName);

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
        logger.d("Thumbnail missing for $videoName. Regenerating...");

        try {
          // 获取视频缩略图
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

  //获取图片宽高
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

  static Future<double> getImageAspectRatio(ImageProvider imageProvider) async {
    final key = _getImageKey(imageProvider);
    final cachedAspectRatio = await _imageAspectRatioCache.get(key);
    if (cachedAspectRatio != null) {
      return cachedAspectRatio;
    }

    final completer = Completer<double>();
    final imageStream = imageProvider.resolve(const ImageConfiguration());

    imageStream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) async {
          final aspectRatio = info.image.width / info.image.height;
          await _imageAspectRatioCache.put(key, aspectRatio);
          if (!completer.isCompleted) {
            completer.complete(aspectRatio);
          }
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );

    return completer.future;
  }

  static String _getImageKey(ImageProvider imageProvider) {
    if (imageProvider is AssetImage) {
      return 'asset_${imageProvider.assetName}';
    } else if (imageProvider is NetworkImage) {
      return 'network_${imageProvider.url}';
    } else if (imageProvider is FileImage) {
      return 'file_${imageProvider.file.path}';
    }
    return imageProvider.toString();
  }

  //获取单个图片，拍照或者相册
  static Future<XFile?> pickPhoto(ImageSource imageSource) async {
    return await _picker.pickImage(source: imageSource);
  }

  //获取单个视频
  static Future<XFile?> pickVideo(ImageSource imageSource) async {
    return await _picker.pickVideo(source: imageSource);
  }

  //异步获取图片颜色
  static Future<int> getColorScheme(ImageProvider imageProvider) async {
    final color =
        (await ColorScheme.fromImageProvider(provider: imageProvider)).primary;
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
  static Future<Uint8List?> compressImageData({
    required String imagePath,
    ImageFormat? imageFormat,
    int? size,
    double? imageAspectRatio,
  }) async {
    final imageFormat_ = imageFormat ?? ImageFormat.getImageFormat(imagePath);
    return await switch (imageFormat_) {
      ImageFormat.jpeg => _compressRust(
        imagePath,
        r_type.CompressFormat.jpeg,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.png => _compressRust(
        imagePath,
        r_type.CompressFormat.png,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.heic => _compressNative(
        imagePath,
        CompressFormat.heic,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
      ImageFormat.webp => _compressRust(
        imagePath,
        r_type.CompressFormat.webP,
        size: size,
        imageAspectRatio: imageAspectRatio,
      ),
    };
  }

  /// 压缩图片并保存到指定路径
  static Future<void> compressAndSaveImage(
    XFile imageFile,
    String outputPath,
    ImageFormat imageFormat,
  ) async {
    if (PrefUtil.getValue<int>('quality') == 3) {
      await imageFile.saveTo(outputPath);
      return;
    }
    final newImage = await compressImageData(
      imagePath: imageFile.path,
      imageFormat: imageFormat,
    );
    if (newImage != null) {
      await File(outputPath).writeAsBytes(newImage);
    } else {
      await imageFile.saveTo(outputPath);
    }
  }

  static Future<Uint8List?> _compressRust(
    String imagePath,
    r_type.CompressFormat format, {
    int? size,
    double? imageAspectRatio,
  }) async {
    final imageSize =
        size ??
        switch (PrefUtil.getValue<int>('quality')) {
          0 => 720,
          1 => 1080,
          2 => 1440,
          _ => 1080,
        };
    final oldPath = imagePath;
    Uint8List? newImage;
    try {
      final imageAspect =
          imageAspectRatio ??
          await ImageCacheUtil().getImageAspectRatioWithCache(
            imagePath: imagePath,
          );

      /// 计算新的宽高
      /// 对于横图，高度为 size，宽度按比例缩放
      /// 对于竖图，宽度为 size，高度按比例缩放
      final width =
          imageAspect < 1.0 ? imageSize : (imageSize * imageAspect).ceil();
      final height =
          imageAspect >= 1.0 ? imageSize : (imageSize / imageAspect).ceil();
      newImage = await ImageCompress.containWithOptions(
        filePath: oldPath,
        targetHeight: height,
        targetWidth: width,
        compressFormat: format,
      );
    } catch (e) {
      logger.d('Image compression failed: $e');
      newImage = null;
    }
    return newImage;
  }

  //图片压缩
  static Future<Uint8List?> _compressNative(
    String imagePath,
    CompressFormat format, {
    int? size,
    double? imageAspectRatio,
  }) async {
    if (Platform.isWindows) {
      return null;
    }
    final quality = PrefUtil.getValue<int>('quality');
    final imageSize =
        size ??
        switch (quality) {
          0 => 720,
          1 => 1080,
          2 => 1440,
          _ => 1080,
        };
    final imageAspect =
        imageAspectRatio ??
        await ImageCacheUtil().getImageAspectRatioWithCache(
          imagePath: imagePath,
        );

    /// 计算新的宽高
    /// 对于横图，宽度为 size，高度按比例缩放
    /// 对于竖图，高度为 size，宽度按比例缩放
    final width =
        imageAspect < 1.0 ? imageSize : (imageSize * imageAspect).ceil();
    final height =
        imageAspect >= 1.0 ? imageSize : (imageSize / imageAspect).ceil();
    final newImage = await FlutterImageCompress.compressWithFile(
      imagePath,
      minHeight: height,
      minWidth: width,
      format: format,
    );
    return newImage;
  }

  //获取视频缩略图
  static Future<bool> _getVideoThumbnail(XFile xFile, destPath) async {
    final quality = PrefUtil.getValue<int>('quality');
    final height = switch (quality) {
      0 => 720,
      1 => 1080,
      2 => 1440,
      _ => 1080,
    };
    return await _thumbnail.getVideoThumbnail(
      srcFile: xFile.path,
      destFile: destPath,
      width: height,
      height: height,
      format: 'jpeg',
      quality: 90,
    );
  }

  // 保存视频或者图片到相册
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
      // 根据媒体文件类型提取日期
      final uuid = image.split('image-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        // 获取日期部分
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
    // 返回按日期排序的分组数据
    final sortedEntries =
        groupedMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  static Map<DateTime, List<String>> groupVideoFileByDate(
    List<String> filePaths,
  ) {
    final Map<DateTime, List<String>> groupedMap = {};
    for (final video in filePaths) {
      // 根据媒体文件类型提取日期
      if (!basename(video).startsWith('video-')) continue;
      final uuid = video.split('video-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        // 获取日期部分
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
    // 返回按日期排序的分组数据
    final sortedEntries =
        groupedMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  static Map<DateTime, List<String>> groupAudioFileByDate(
    List<String> filePaths,
  ) {
    final Map<DateTime, List<String>> groupedMap = {};
    for (final audio in filePaths) {
      // 根据媒体文件类型提取日期
      final uuid = audio.split('audio-')[1].split('.')[0];
      final dateTime = MediaUtil.extractDateFromUUID(uuid);
      if (dateTime != null) {
        // 获取日期部分
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
    // 返回按日期排序的分组数据
    final sortedEntries =
        groupedMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }
}
