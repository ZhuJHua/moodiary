import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:gal/gal.dart';
import 'package:mime/mime.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart';

class MediaManager {
  static final _thumbnail = FcNativeVideoThumbnail();

  /// 返回 map：key=XFile 临时路径，value=实际文件名。
  static Future<Map<String, String>> saveImages({
    required List<XFile> imageFileList,
  }) async {
    final imageNameMap = <String, String>{};
    await Future.wait(
      imageFileList.map((imageFile) async {
        final name = await saveImage(imageFile);
        if (name != null) imageNameMap[imageFile.path] = name;
      }),
    );
    return imageNameMap;
  }

  /// 图片入库：**原字节直存**，不缩不转码 —— 用户的图我们不动。只有 HEIC 例外：
  /// Flutter 与 webview 两端都解不了，且都是相机成片没有透明通道，固定转 JPG。
  /// 后缀按魔数定（picker 吐的临时文件名不可信），从此后缀就是真实格式。
  /// 落盘后 fire-and-forget 预热缩略图档位（[FastImageDerivatives.warm]）。
  /// 已是 image- 命名的（重复插入）直接复用。失败返回 null。
  static Future<String?> saveImage(XFile imageFile) async {
    final srcName = basename(imageFile.path);
    if (srcName.startsWith('image-')) return srcName;
    try {
      final mime = await _sniffMime(imageFile.path);
      final String name;
      if (mime == 'image/heic' || mime == 'image/heif') {
        name = 'image-${uuidV7()}.jpg';
        final out = await IHeifDecoder.get().convert(
          imageFile.path,
          outputPath: AppFiles.getRealPath('image', name),
          format: 'jpg',
        );
        if (out == null) return null;
      } else {
        name = 'image-${uuidV7()}${_extensionFor(mime, imageFile.path)}';
        await imageFile.saveTo(AppFiles.getRealPath('image', name));
      }
      unawaited(FastImageDerivatives.warm(AppFiles.getRealPath('image', name)));
      return name;
    } catch (e) {
      logger.d('saveImage failed: ${imageFile.path} ($e)');
      return null;
    }
  }

  /// 读文件头识别 MIME，认不出再退回按后缀。
  static Future<String?> _sniffMime(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final header = await raf.read(defaultMagicNumbersMaxLength);
      return lookupMimeType(path, headerBytes: header);
    } catch (_) {
      return lookupMimeType(path);
    } finally {
      await raf?.close();
    }
  }

  static String _extensionFor(String? mime, String path) {
    return switch (mime) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/bmp' => '.bmp',
      _ => extension(path).isNotEmpty ? extension(path).toLowerCase() : '.jpg',
    };
  }

  /// 返回 map：key=缓存路径，value=实际文件名
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

  static Future<bool> _getVideoThumbnail(XFile xFile, destPath) async {
    // 封面仅用于列表 / 网格展示，与图片 m 档位同宽。
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
      if (type == .video) {
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
    return .fromMillisecondsSinceEpoch(timestampInt);
  }

  /// 根据日期分组文件
}
