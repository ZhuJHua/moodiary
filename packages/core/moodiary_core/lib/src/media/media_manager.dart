import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:mime/mime.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/src/app_logger.dart';
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

class MediaManager {
  static final _thumbnail = FcNativeVideoThumbnail();

  /// 图片优化开关：开 = 1280 规则压缩 + 统一 WebP（Rust optimizeToFile）；
  /// 关 = 原图直存（HEIC 例外，平台兼容性必须转码）。
  static bool get _optimizeEnabled => MoodiaryKVs.imageOptimize.get() ?? true;

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
        // HEIC 在 Rust 侧无法解码且平台兼容性差，必须转码（与优化开关无关）：
        // 先转 PNG 临时文件；优化开启时最终格式统一 WebP（自带 alpha，无需探测），
        // 关闭时按是否含 alpha 选 PNG（保透明）/ JPEG（省体积）。
        String? heicTempPath;
        if (imageFormat == ImageFormat.heic) {
          heicTempPath = await _convertHeicToPng(imageFile.path);
          if (heicTempPath != null) {
            workingFile = XFile(heicTempPath);
            imageFormat = _optimizeEnabled
                ? ImageFormat.webp
                : (await _pngHasAlphaChannel(heicTempPath)
                      ? ImageFormat.png
                      : ImageFormat.jpeg);
          }
        } else if (_optimizeEnabled) {
          imageFormat = ImageFormat.webp;
        }
        try {
          final imageName = 'image-${uuidV7()}${imageFormat.extension}';
          final outputPath = AppFiles.getRealPath('image', imageName);
          await compressAndSaveImage(workingFile, outputPath);
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

  /// 乐观插入用：把选中原图快速落到 image 目录并返回文件名，供 UI 立即显示——**不做重压缩**，
  /// 只做「让它能显示」的最小工作。HEIC 无法在 webview 直接渲染，先原生解码为 PNG，据其色彩类型
  /// 判断是否含透明通道：含 → 存 PNG（保留 alpha）；不含（普通不透明照片）→ 再原生解码为 JPEG
  /// 并弃掉 PNG（省体积）。两步均为原生解码，仍很快。其余格式直接拷贝原字节。随后由
  /// [compressInPlace] 后台就地压缩、无感替换。已是 image- 命名的（重复插入）直接复用。失败返回 null。
  static Future<String?> materializeOriginal(XFile imageFile) async {
    final srcName = basename(imageFile.path);
    if (srcName.startsWith('image-')) return srcName;
    final format = ImageFormat.getImageFormat(imageFile.path);
    if (format == ImageFormat.heic) {
      final uuid = uuidV7();
      if (_optimizeEnabled) {
        // 转 PNG 字节直接落 .webp 名（HeifConverter 按输出后缀选编码器，非 .jpg
        // 即 PNG；webview 按内容嗅探可显示），后台 compressInPlace 就地转真 WebP
        // （WebP 自带 alpha，无需探测）。
        final name = 'image-$uuid.webp';
        try {
          final out = await HeifConverter.convert(
            imageFile.path,
            output: AppFiles.getRealPath('image', name),
            format: 'png',
          );
          return out == null ? null : name;
        } catch (e) {
          logger.d('materializeOriginal HEIC -> PNG failed: $e');
          return null;
        }
      }
      // 优化关闭：转码即定稿（无后台压缩），按 alpha 选 PNG / JPEG。
      final pngName = 'image-$uuid.png';
      final pngPath = AppFiles.getRealPath('image', pngName);
      try {
        final out = await HeifConverter.convert(
          imageFile.path,
          output: pngPath,
          format: 'png',
        );
        if (out == null) return null;
      } catch (e) {
        logger.d('materializeOriginal HEIC -> PNG failed: $e');
        return null;
      }
      // 含 alpha 通道 → 保留 PNG。
      if (await _pngHasAlphaChannel(pngPath)) return pngName;
      // 不透明 → 转 JPEG 省体积；转换失败则退回已生成的 PNG。
      final jpgName = 'image-$uuid.jpg';
      try {
        final out = await HeifConverter.convert(
          imageFile.path,
          output: AppFiles.getRealPath('image', jpgName),
          format: 'jpg',
        );
        if (out == null) return pngName;
        try {
          await File(pngPath).delete();
        } catch (_) {}
        return jpgName;
      } catch (e) {
        logger.d('materializeOriginal HEIC -> JPEG failed: $e');
        return pngName;
      }
    }
    // 开优化：原字节先落 .webp 名快速显示（内容后缀暂不符，靠嗅探），后台就地转真 WebP；
    // 关优化：按源格式原样落盘即定稿。
    final name = _optimizeEnabled
        ? 'image-${uuidV7()}.webp'
        : 'image-${uuidV7()}${format.extension}';
    await File(imageFile.path).copy(AppFiles.getRealPath('image', name));
    return name;
  }

  /// 读 PNG 文件头判断是否含 alpha 通道（IHDR 第 25 字节的 color type：4=灰度+alpha、
  /// 6=真彩+alpha）。只读头 26 字节，无需解码整图。非 PNG / 读失败按「无 alpha」处理。
  static Future<bool> _pngHasAlphaChannel(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final header = await raf.read(26);
      if (header.length < 26) return false;
      final colorType = header[25];
      return colorType == 4 || colorType == 6;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  /// [materializeOriginal] 的后台步骤：把已落库的 image- 文件就地统一优化
  /// （1280 规则 + WebP）。压到临时文件再原子重命名替换——避免与 webview 读取竞态、
  /// 中断也不损坏原文件。优化关闭（原图直存）或失败时保留原文件。fire-and-forget，
  /// 与任何 widget 生命周期无关。
  static Future<void> compressInPlace(String imageName) async {
    if (!_optimizeEnabled) return;
    final path = AppFiles.getRealPath('image', imageName);
    final tmpPath = '$path.tmp';
    final ok = await _optimizeRustToFile(path, tmpPath);
    if (!ok) {
      try {
        await File(tmpPath).delete();
      } catch (_) {}
      return;
    }
    try {
      await File(tmpPath).rename(path);
    } catch (_) {
      try {
        await File(tmpPath).delete();
      } catch (_) {}
    }
  }

  /// 返回 map：key=缓存路径，value=实际文件名
  static Future<Map<String, String>> saveAudio(List<String> audioNames) async {
    final audioNameMap = <String, String>{};
    await Future.wait(
      audioNames.map((name) async {
        final file = File(AppFiles.getCachePath(name));
        final targetPath = AppFiles.getRealPath('audio', name);
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
        await videoFile.saveTo(AppFiles.getRealPath('video', videoName));
        final tempThumbnailPath = AppFiles.getRealPath('thumbnail', videoName);
        await _getVideoThumbnail(videoFile, tempThumbnailPath);
      }),
    );

    return videoNameMap;
  }

  static Future<void> regenerateMissingThumbnails() async {
    String getThumbnailPath(String videoName) =>
        AppFiles.getRealPath('thumbnail', videoName);

    final videoDir = Directory(AppFiles.getRealPath('video', ''));
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

  static Future<int> getColorScheme(ImageProvider imageProvider) async {
    final color = (await ColorScheme.fromImageProvider(
      provider: imageProvider,
    )).primary;
    return ((color.a * 255).toInt() << 24) |
        ((color.r * 255).toInt() << 16) |
        ((color.g * 255).toInt() << 8) |
        (color.b * 255).toInt();
  }

  /// Rust 解码+缩放后直接写 outputPath，像素不经 FFI 拷贝到 Dart 堆。
  /// 返回 true=已写入；false=失败，调用方自行兜底。
  static Future<bool> compressImageToFile({
    required String imagePath,
    required String outputPath,
    required int size,
    ImageFormat? imageFormat,
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

  /// 开优化：Rust 统一优化（1280 规则 + WebP）；关：原样落盘（HEIC 已在上游转码）。
  /// 优化失败兜底存原字节——文件名后缀可能与内容不符，webview 按内容嗅探仍可显示。
  static Future<void> compressAndSaveImage(
    XFile imageFile,
    String outputPath,
  ) async {
    if (!_optimizeEnabled) {
      await imageFile.saveTo(outputPath);
      return;
    }
    final ok = await _optimizeRustToFile(imageFile.path, outputPath);
    if (!ok) {
      await imageFile.saveTo(outputPath);
    }
  }

  static Future<bool> _optimizeRustToFile(
    String imagePath,
    String outputPath,
  ) async {
    try {
      await rust.ImageCompressor.optimizeToFile(
        filePath: imagePath,
        outputPath: outputPath,
      );
      return true;
    } catch (e) {
      logger.d('Image optimize failed: $e');
      return false;
    }
  }

  /// HEIC 不能被 Rust 直接解码，先转 PNG 临时文件再压缩，最后清理。转 PNG（而非 JPEG）
  /// 以保留可能存在的透明像素（HEIC 可含 alpha，JPEG 会丢失）。
  static Future<bool> _compressHeicToFile(
    String imagePath,
    String outputPath, {
    required int size,
    double? imageAspectRatio,
  }) async {
    final tempPath = await _convertHeicToPng(imagePath);
    if (tempPath == null) return false;
    try {
      return await _compressRustToFile(
        tempPath,
        outputPath,
        rust.CompressFormat.png,
        size: size,
        imageAspectRatio: imageAspectRatio,
      );
    } finally {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  /// 转 PNG 临时文件（保留 alpha），调用方负责清理。heif_converter 的 Android 实现按输出路径
  /// 后缀选编码器（非 .jpg/.jpeg 即 PNG，`Bitmap.compress(PNG, 100)` 无损含 alpha）。
  static Future<String?> _convertHeicToPng(String heicPath) async {
    try {
      final tempPngPath = '${Directory.systemTemp.path}/heic_${uuidV7()}.png';
      return await HeifConverter.convert(
        heicPath,
        output: tempPngPath,
        format: 'png',
      );
    } catch (e) {
      logger.d('HEIC -> PNG conversion failed: $e');
      return null;
    }
  }

  static Future<bool> _compressRustToFile(
    String imagePath,
    String outputPath,
    rust.CompressFormat format, {
    required int size,
    double? imageAspectRatio,
  }) async {
    try {
      final imageAspect =
          imageAspectRatio ??
          await ImageSizeManager().getAspectRatioAsync(imagePath);

      // 横图：高度为 size，宽度按比例缩放；竖图反之。
      final width = imageAspect < 1.0 ? size : (size * imageAspect).ceil();
      final height = imageAspect >= 1.0 ? size : (size / imageAspect).ceil();
      await rust.ImageCompressor.containToFile(
        filePath: imagePath,
        outputPath: outputPath,
        spec: rust.CompressSpec(
          targetHeight: height,
          targetWidth: width,
          compressFormat: format,
        ),
      );
      return true;
    } catch (e) {
      logger.d('Image compression failed: $e');
      return false;
    }
  }

  static Future<bool> _getVideoThumbnail(XFile xFile, destPath) async {
    // 与图片优化的尺寸上限一致（封面仅用于列表/网格展示）。
    const size = 1280;
    return await _thumbnail.saveThumbnailToFile(
      srcFile: xFile.path,
      destFile: destPath,
      width: size,
      height: size,
      format: 'jpeg',
      quality: 90,
    );
  }

  /// 存入系统相册（Moodiary 相簿）。返回是否成功，提示语由调用方按 l10n 处理。
  static Future<bool> saveToGallery({
    required String path,
    required MediaType type,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);
      if (type == MediaType.video) {
        await Gal.putVideo(path, album: 'Moodiary');
      } else {
        await Gal.putImage(path, album: 'Moodiary');
      }
      return true;
    } catch (e) {
      logger.d('saveToGallery failed: $e');
      return false;
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
      final dateTime = MediaManager.extractDateFromUUID(uuid);
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
      final dateTime = MediaManager.extractDateFromUUID(uuid);
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
      final dateTime = MediaManager.extractDateFromUUID(uuid);
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
