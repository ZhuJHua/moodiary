import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'derivatives.dart';

/// 本地图片的 [ImageProvider]。相对 `ResizeImage(FileImage(...))` 多做两件事，
/// 都在 [FastImageDerivatives] 那层：
///
/// - 给了 [tier] 就取该档位的磁盘缩略图（只查不生成），此后每次滚动只解几十 KB。
///   档位还没生成的（存量图片、预热没跑完）拿到的是原图，按档位宽夹住解码：JPEG 走
///   DCT 缩放，位图不大，但熵解码仍是全量的，一屏十几张就是几百毫秒的 IO 线程排队。
///   [tier] 为 null 才碰原图（看图页）。
/// - 历史 `.heic` 不在这里救：照旧破图，直到用户在「设置 → 数据 → 图片优化」转成 JPG。
///
/// **缓存键是（路径, 档位, decodeWidth），不含格子宽。** 折叠屏展开 / 转屏 / 分屏时格子
/// 宽度连续变化，按格子宽做键会让可见的每一格重新解码、重新淡入一遍；按档位做键，
/// 只要没跨档就一次都不重载。位图按缩略图原尺寸解（512 宽约 0.75MB），交给 GPU 缩到
/// 格子。**固定尺寸的容器**（日历格、44dp 封面）可传 [decodeWidth] 把解码夹小，那种
/// 容器的宽不随布局变，键仍稳定。
///
/// 看图页（无档位、无 [decodeWidth]）按最长边 [viewerMaxSide] 封顶：photo_view 最大缩放
/// covered×3，超出的像素在屏上看不到，而 48MP 不封顶一张就是 192MB 位图（Impeller 还会
/// 按 GPU 最大纹理再夹一道，等于上限随设备漂）。12MP 以内一个像素不丢；再往上想放大看
/// 细节得做可见区域分块解码，dart:ui 没有区域解码，那是另一件事。
@immutable
class FastImage extends ImageProvider<FastImage> {
  /// 看图页解码上限（最长边，物理像素）。
  static const viewerMaxSide = 4096;

  /// 图片文件绝对路径。
  final String path;

  /// 取哪一档缩略图；null = 解原图（最长边封顶 [viewerMaxSide]），看图页用。
  final FastImageTier? tier;

  /// 固定尺寸容器的解码宽（物理像素），只缩不放大。随布局变化的容器**不要传**。
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
      // ImageCache 只在成功时把 pending 条目转正，失败的会带着错误一直留在
      // pending 表里：同一个 key 再来（文件晚到了、重建了 Image）拿到的还是那次
      // 失败。自己把它踢出去，下次才是真的重试。
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
    // 文件缺失在这里抛，与 FileImage 一样落到调用方的 errorBuilder。
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    // 取了档位但拿回的是原图（小图 / 还没生成 / HEIC）时按档位宽夹住，别把全分辨率
    // 原件解进缓存；拿回的是缩略图本身（或更大一档）时夹到档位宽。
    final maxWidth = key.decodeWidth ?? tier?.width;
    return decode(
      buffer,
      getTargetSize: (int w, int h) => maxWidth == null
          ? _fitSide(w, h, viewerMaxSide)
          : _fitWidth(w, h, maxWidth),
    );
  }

  /// 派生物的高最多是宽的几倍（与 Rust 侧 `TIER_MAX_ASPECT` 一致）：档位缺失退回原图时，
  /// 一张 1000×30000 的长截图不能解成 512×15360、31MB 的位图。
  static const _maxAspect = 3;

  /// 按宽夹、再按高夹，永不放大；边长夹到至少 1（细长图按比例算出来会是 0）。
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
