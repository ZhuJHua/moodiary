import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mui/mui.dart';
import 'package:photo_manager/photo_manager.dart';

@immutable
class AssetThumbImage extends ImageProvider<AssetThumbImage> {
  const AssetThumbImage(
    this.entity, {
    required this.width,
    required this.height,
    this.quality = 88,
  });

  factory AssetThumbImage.origin(AssetEntity entity, {int quality = 95}) {
    final width = entity.orientatedWidth;
    final height = entity.orientatedHeight;
    final longest = width > height ? width : height;
    if (longest <= 0) {
      return AssetThumbImage(
        entity,
        width: maxOriginSide,
        height: maxOriginSide,
        quality: quality,
      );
    }
    final scale = longest > maxOriginSide ? maxOriginSide / longest : 1.0;
    return AssetThumbImage(
      entity,
      width: (width * scale).round().clamp(1, maxOriginSide),
      height: (height * scale).round().clamp(1, maxOriginSide),
      quality: quality,
    );
  }

  static const int maxOriginSide = 2560;

  final AssetEntity entity;
  final int width;
  final int height;
  final int quality;

  @override
  Future<AssetThumbImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AssetThumbImage>(this);

  @override
  ImageStreamCompleter loadImage(
    AssetThumbImage key,
    ImageDecoderCallback decode,
  ) {
    final cancelToken = PMCancelToken(debugLabel: key.entity.id);
    var settled = false;
    final completer = MultiFrameImageStreamCompleter(
      codec: _load(key, decode, cancelToken).whenComplete(() => settled = true),
      scale: 1,
      debugLabel: '${key.entity.id}@${key.width}x${key.height}',
      informationCollector: () => [
        DiagnosticsProperty<AssetEntity>('asset', key.entity),
      ],
    );
    completer.addOnLastListenerRemovedCallback(() {
      if (settled) return;
      unawaited(cancelToken.cancelRequest());
      // 撤掉的那次不能留在缓存里当「失败」，否则滚回来还是空的。
      PaintingBinding.instance.imageCache.evict(key);
    });
    return completer;
  }

  Future<ui.Codec> _load(
    AssetThumbImage key,
    ImageDecoderCallback decode,
    PMCancelToken cancelToken,
  ) async {
    final data = await key.entity.thumbnailDataWithOption(
      ThumbnailOption(
        size: ThumbnailSize(key.width, key.height),
        quality: key.quality,
      ),
      cancelToken: cancelToken,
    );
    if (data == null || data.isEmpty) {
      throw StateError('thumbnail unavailable: ${key.entity.id}');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(data));
  }

  // 按 id 比较，不用 AssetEntity==（它把 isFavorite/isTrashed 也计入，收藏一下就会整条缓存 miss）
  @override
  bool operator ==(Object other) =>
      other is AssetThumbImage &&
      other.entity.id == entity.id &&
      other.width == width &&
      other.height == height &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(entity.id, width, height, quality);

  @override
  String toString() => 'AssetThumbImage(${entity.id}, $width×$height)';
}
