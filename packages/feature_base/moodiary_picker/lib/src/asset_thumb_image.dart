import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mui/mui.dart';
import 'package:photo_manager/photo_manager.dart';

/// 相册资源的图片源。**刻意不用 photo_manager_image_provider**，那个包有四处
/// 实测过的问题：包级 `_lockImageTypes` 只增不删且强引用 [AssetEntity]（滚过上万
/// 张就是上万条，`imageCache.clear()` 也清不掉）、iOS 上每格多一次 `titleAsync`
/// 平台往返、`_getType` 里 `mimeType.split('.')` 用错导致安卓 HEIC 走错分支、
/// 以及它一个 [PMCancelToken] 都不暴露。
///
/// 这里只做三件事：按 id + 尺寸做缓存键、走 [PMCancelToken] 取缩略图、
/// 最后一个监听者离开时把还在原生排队的请求撤掉 —— photo_manager 的 Android
/// 线程池是 8 核 + 无界队列，不撤就得把快速滚动排进去的成千次请求全部执行完。
///
/// **一律走缩略图，不走 `loadFile(isOrigin: true)`**：原图路径会把 HEIC 原始
/// 字节喂给 Flutter 解码（解不了），而按原始尺寸取缩略图等于让原生后台线程转出
/// JPEG，顺带把 HEIC 这件事在源头解决。
@immutable
class AssetThumbImage extends ImageProvider<AssetThumbImage> {
  const AssetThumbImage(
    this.entity, {
    required this.width,
    required this.height,
    this.quality = 88,
  });

  /// 按资源原始像素取图（预览页用）。上限 [maxOriginSide] 是为了让超大图不至于
  /// 一张就吃掉整个 ImageCache。
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

  /// 按 id 而不是按 [AssetEntity] 比 —— 它的 `==` 把 `isFavorite` / `isTrashed`
  /// 也算进去了，用户在系统相册点一下收藏就会让缓存整条 miss。
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
