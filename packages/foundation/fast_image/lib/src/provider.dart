import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'derivatives.dart';

@immutable
class FastImage extends ImageProvider<FastImage> {
  static const viewerMaxSide = 4096;

  final String path;

  final FastImageTier? tier;

  final int? decodeWidth;

  const FastImage(this.path, {this.tier, this.decodeWidth});

  @override
  Future<FastImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FastImage>(this);

  @override
  ImageStreamCompleter loadImage(FastImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: key.path,
      informationCollector: () => [ErrorDescription('Path: ${key.path}')],
    );
  }

  Future<ui.Codec> _load(FastImage key, ImageDecoderCallback decode) async {
    try {
      return await _loadUnchecked(key, decode);
    } catch (_) {
      // ImageCache 失败的 pending 条目不会自动转正，需手动 evict 才能重试
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
  }

  Future<ui.Codec> _loadUnchecked(
    FastImage key,
    ImageDecoderCallback decode,
  ) async {
    final tier = key.tier;
    final path = tier == null
        ? key.path
        : await FastImageDerivatives.resolve(key.path, tier: tier);
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final maxWidth = key.decodeWidth ?? tier?.width;
    return decode(
      buffer,
      getTargetSize: (int w, int h) => maxWidth == null
          ? _fitSide(w, h, viewerMaxSide)
          : _fitWidth(w, h, maxWidth),
    );
  }

  // 必须与 Rust 侧 TIER_MAX_ASPECT 一致
  static const _maxAspect = 3;

  static ui.TargetImageSize _fitWidth(int w, int h, int maxWidth) {
    final scale = math.min(
      math.min(maxWidth / w, maxWidth * _maxAspect / h),
      1.0,
    );
    if (scale >= 1) return ui.TargetImageSize(width: w, height: h);
    return ui.TargetImageSize(
      width: (w * scale).round().clamp(1, w),
      height: (h * scale).round().clamp(1, h),
    );
  }

  static ui.TargetImageSize _fitSide(int w, int h, int maxSide) {
    final side = w > h ? w : h;
    if (side <= maxSide) return ui.TargetImageSize(width: w, height: h);
    return ui.TargetImageSize(
      width: (w * maxSide / side).round().clamp(1, w),
      height: (h * maxSide / side).round().clamp(1, h),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FastImage &&
      other.path == path &&
      other.tier == tier &&
      other.decodeWidth == decodeWidth;

  @override
  int get hashCode => Object.hash(path, tier, decodeWidth);

  @override
  String toString() =>
      'FastImage("$path", tier: ${tier?.name}, decodeWidth: $decodeWidth)';
}
