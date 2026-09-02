import 'dart:ui' as ui;

// material_ui 不转发 SynchronousFuture，取用得回 flutter/foundation（同 mui 自己的 delegate）。
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:mui/mui.dart';

import 'image_derivatives.dart';

/// 本地图片的 [ImageProvider]。相对 `ResizeImage(FileImage(...))` 多做两件事，
/// 都在 [ImageDerivatives] 那层：
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
class MediaImage extends ImageProvider<MediaImage> {
  /// 看图页解码上限（最长边，物理像素）。
  static const viewerMaxSide = 4096;

  /// 图片文件绝对路径。
  final String path;

  /// 取哪一档缩略图；null = 解原图（最长边封顶 [viewerMaxSide]），看图页用。
  final ImageTier? tier;

  /// 固定尺寸容器的解码宽（物理像素），只缩不放大。随布局变化的容器**不要传**。
  final int? decodeWidth;

  const MediaImage(this.path, {this.tier, this.decodeWidth});

  @override
  Future<MediaImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<MediaImage>(this);

  @override
  ImageStreamCompleter loadImage(MediaImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: key.path,
      informationCollector: () => [ErrorDescription('Path: ${key.path}')],
    );
  }

  Future<ui.Codec> _load(MediaImage key, ImageDecoderCallback decode) async {
    final tier = key.tier;
    final path = tier == null
        ? key.path
        : await ImageDerivatives.resolve(key.path, tier: tier);
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

  /// 高度夹到至少 1：细长图（4000x3 之类）按比例算出来会是 0。
  static ui.TargetImageSize _fitWidth(int w, int h, int maxWidth) =>
      w <= maxWidth
      ? ui.TargetImageSize(width: w, height: h)
      : ui.TargetImageSize(
          width: maxWidth,
          height: (h * maxWidth / w).round().clamp(1, h),
        );

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
      other is MediaImage &&
      other.path == path &&
      other.tier == tier &&
      other.decodeWidth == decodeWidth;

  @override
  int get hashCode => Object.hash(path, tier, decodeWidth);

  @override
  String toString() =>
      'MediaImage("$path", tier: ${tier?.name}, decodeWidth: $decodeWidth)';
}
