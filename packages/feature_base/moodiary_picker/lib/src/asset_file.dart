import 'dart:io';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show uuidV7;
import 'package:photo_manager/photo_manager.dart';

// 缓存文件命名 picked-<uuid>.<ext>：不以 image-/video- 开头，避免被 MediaManager 当作已落库、或被 scanOrphanMedia 当孤儿清理
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

// iOS 同步 mimeType 恒为 null，异步版才有值
Future<bool> _isHeif(AssetEntity asset) async {
  final mime = asset.mimeType ?? await asset.mimeTypeAsync;
  return mime == 'image/heic' || mime == 'image/heif';
}

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

// PMProgressHandler 每 new 一个就永久占一条 MethodChannel，没有回收路径，只在确实不在本地时才建
Future<PMProgressHandler?> _cloudHandlerFor(AssetEntity asset) async {
  if (!Platform.isIOS && !Platform.isMacOS) return null;
  try {
    if (await asset.isLocallyAvailable(isOrigin: true)) return null;
  } catch (_) {
    return null;
  }
  return PMProgressHandler();
}
