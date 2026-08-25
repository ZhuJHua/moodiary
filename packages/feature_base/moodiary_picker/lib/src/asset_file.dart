import 'dart:io';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show uuidV7;
import 'package:photo_manager/photo_manager.dart';

/// 把相册资源交成 [XFile]。**这里是 picker 输出契约的全部** —— 压缩、选格式、
/// 落 image 目录都是下游 `MediaManager` 的事，别在这里替它们做决定。
///
/// 写出的缓存文件一律叫 `picked-<uuid>.<ext>`：不以 `image-` / `video-` 开头，
/// 免得被 MediaManager 当成「已落库」跳过处理；也不在 `scanOrphanMedia` 的
/// 扫描范围内（那只扫 image/video/audio 三个真实目录），不会被误判成孤儿。
Future<List<XFile>> assetsToFiles(List<AssetEntity> assets) async {
  final files = await Future.wait(assets.map(assetToFile));
  return files.whereType<XFile>().toList();
}

Future<XFile?> assetToFile(AssetEntity asset) async {
  try {
    if (asset.type == AssetType.image && await _isHeif(asset)) {
      final converted = await _heifToJpeg(asset);
      if (converted != null) return converted;
    }
    final file = await _originFile(asset);
    return file == null ? null : XFile(file.path);
  } catch (e) {
    logger.d('asset -> file failed(${asset.id}): $e');
    return null;
  }
}

/// mimeType 用**全等**比，不要 `split('.')` 那套 ——
/// `'image/heic'.split('.').last` 切出来还是整串，会让判定悄悄走错分支。
/// iOS 的同步 `mimeType` 恒为 null，异步版才有值。
Future<bool> _isHeif(AssetEntity asset) async {
  final mime = asset.mimeType ?? await asset.mimeTypeAsync;
  return mime == 'image/heic' || mime == 'image/heif';
}

/// HEIC 不取 originFile：heif_converter 的 Android 实现在主线程同步解码 + 编码
/// （整个 App 冻住）。改让 photo_manager 在原生后台线程按原始尺寸转出 JPEG
/// （q95，照片无 alpha 顾虑），下游管线从此见不到 HEIC。
///
/// 这段之所以留在 picker 而不是下沉到 MediaManager：它需要 [AssetEntity]
/// 这个原生相册句柄，一旦拿到 originFile 就只剩一个 HEIC 文件路径了。
Future<XFile?> _heifToJpeg(AssetEntity asset) async {
  // ThumbnailSize(0, 0) 在原生侧行为不确定，宽高取不到就回落原图路径。
  if (asset.width <= 0 || asset.height <= 0) return null;
  try {
    final handler = await _cloudHandlerFor(asset);
    final data = await asset.thumbnailDataWithSize(
      ThumbnailSize(asset.width, asset.height),
      quality: 95,
      progressHandler: handler,
    );
    if (data == null || data.isEmpty) return null;
    final path = AppFiles.getCachePath('picked-${uuidV7()}.jpg');
    await File(path).writeAsBytes(data);
    return XFile(path);
  } catch (e) {
    logger.d('HEIF -> JPEG via photo_manager failed: $e');
    return null;
  }
}

Future<File?> _originFile(AssetEntity asset) async {
  final handler = await _cloudHandlerFor(asset);
  return asset.loadFile(isOrigin: true, progressHandler: handler);
}

/// [PMProgressHandler] 每 new 一个就永久占一条 MethodChannel（构造函数里自增
/// index 并 setMethodCallHandler，没有任何回收路径），所以只在「确实不在本地」
/// 时才建。Android 侧 `isLocallyAvailable` 直接返回 true，这一整套只对 Apple
/// 平台花钱。
Future<PMProgressHandler?> _cloudHandlerFor(AssetEntity asset) async {
  if (!Platform.isIOS && !Platform.isMacOS) return null;
  try {
    if (await asset.isLocallyAvailable(isOrigin: true)) return null;
  } catch (_) {
    return null;
  }
  return PMProgressHandler();
}
