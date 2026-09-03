import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// 看图页 tile 规划（纯函数，不碰 widget）。模型参考 pixa：2 的幂 sampleSize、
/// [tileSize] 源像素见方的 tile、可见 tile 按离视口中心距离排序、封顶、外圈预取。
///
/// 坐标全部是**转正后的源像素**；解码由 Rust 按 sampleSize 缩放（`denom`）出 RGBA。
class FastTilePlanner {
  /// 源图尺寸（转正后）。
  final Size imageSize;

  /// tile 边长（源像素，未缩放前）。
  final int tileSize;

  /// 视口之外再预取几屏。半屏：一块 tile 是 1MB 的 RGBA，整圈一屏要预取可见数的八倍。
  final double cacheExtentScreens;

  /// 可见 tile 上限（超过就升一档 sample）。密度带下沿（每源像素 0.575 物理像素）一块 tile
  /// 只有 295 物理像素，1440×3200 的竖屏平移到不对齐时可见 6×12 = 72 块；上限比它高，
  /// 不然平移一下就升档、整屏变糊。
  final int maxVisibleTiles;

  /// 可见 + 预取的总上限：上层缓存不淘汰规划内的块，这就是它的内存上界（1MB 一块）。
  /// 可见已经超过它时只留可见。
  final int maxPlannedTiles;

  const FastTilePlanner({
    required this.imageSize,
    this.tileSize = 512,
    this.cacheExtentScreens = 0.5,
    this.maxVisibleTiles = 96,
    this.maxPlannedTiles = 64,
  });

  /// [visible] 视口在源像素坐标里的矩形；[physicalScale] 每个源像素占多少物理像素。
  FastTilePlan plan({required Rect visible, required double physicalScale}) {
    final bounds = Offset.zero & imageSize;
    final visibleRect = visible.intersect(bounds);
    if (visibleRect.isEmpty ||
        visibleRect.width <= 0 ||
        visibleRect.height <= 0) {
      return const FastTilePlan(sample: 1, visible: [], prefetch: []);
    }
    var sample = _chooseSample(physicalScale);
    var raw = _rawPlan(visibleRect, sample);
    while (raw.visible.length > maxVisibleTiles && sample < _maxSample) {
      sample *= 2;
      raw = _rawPlan(visibleRect, sample);
    }
    final shown = raw.visible.take(maxVisibleTiles).toList(growable: false);
    return FastTilePlan(
      sample: sample,
      visible: shown,
      prefetch: raw.prefetch
          .take((maxPlannedTiles - shown.length).clamp(0, maxPlannedTiles))
          .toList(growable: false),
    );
  }

  static const _maxSample = 8;

  /// 解出的像素密度落在屏幕的 0.58–1.15 倍之间：够清晰，又不多解一倍。
  int _chooseSample(double physicalScale) {
    final scale = math.max(physicalScale, 1e-6);
    var sample = 1;
    while (sample < _maxSample && scale * sample * 2 <= 1.15) {
      sample *= 2;
    }
    return sample;
  }

  ({List<FastTileSpec> visible, List<FastTileSpec> prefetch}) _rawPlan(
    Rect visibleRect,
    int sample,
  ) {
    final center = visibleRect.center;
    final visible = _tilesFor(visibleRect, sample)..sort(_byDistance(center));
    final keys = {for (final t in visible) t.key};
    final cacheRect = visibleRect
        .inflate(0)
        .expandToInclude(
          Rect.fromCenter(
            center: center,
            width: visibleRect.width * (1 + 2 * cacheExtentScreens),
            height: visibleRect.height * (1 + 2 * cacheExtentScreens),
          ),
        )
        .intersect(Offset.zero & imageSize);
    final prefetch = _tilesFor(
      cacheRect,
      sample,
    ).where((t) => !keys.contains(t.key)).toList()..sort(_byDistance(center));
    return (visible: visible, prefetch: prefetch);
  }

  static int Function(FastTileSpec, FastTileSpec) _byDistance(Offset center) =>
      (a, b) => (a.sourceRect.center - center).distanceSquared.compareTo(
        (b.sourceRect.center - center).distanceSquared,
      );

  List<FastTileSpec> _tilesFor(Rect rect, int sample) {
    final span = (tileSize * sample).toDouble();
    final maxCol = math.max(0, ((imageSize.width - 1) / span).floor());
    final maxRow = math.max(0, ((imageSize.height - 1) / span).floor());
    final firstCol = (rect.left / span).floor().clamp(0, maxCol);
    final lastCol = ((rect.right - 0.001) / span).floor().clamp(
      firstCol,
      maxCol,
    );
    final firstRow = (rect.top / span).floor().clamp(0, maxRow);
    final lastRow = ((rect.bottom - 0.001) / span).floor().clamp(
      firstRow,
      maxRow,
    );
    return [
      for (var row = firstRow; row <= lastRow; row++)
        for (var col = firstCol; col <= lastCol; col++)
          FastTileSpec(
            sample: sample,
            row: row,
            col: col,
            sourceRect: Rect.fromLTRB(
              col * span,
              row * span,
              math.min((col + 1) * span, imageSize.width),
              math.min((row + 1) * span, imageSize.height),
            ),
          ),
    ];
  }
}

class FastTilePlan {
  final int sample;

  /// 与视口相交的 tile，按离中心距离排序。
  final List<FastTileSpec> visible;

  /// 视口外圈、值得先解的 tile。
  final List<FastTileSpec> prefetch;

  const FastTilePlan({
    required this.sample,
    required this.visible,
    required this.prefetch,
  });
}

class FastTileSpec {
  final int sample;
  final int row;
  final int col;

  /// 这块 tile 覆盖的源像素矩形（未对齐 iMCU；实际覆盖以解码结果为准）。
  final Rect sourceRect;

  const FastTileSpec({
    required this.sample,
    required this.row,
    required this.col,
    required this.sourceRect,
  });

  String get key => 's$sample-r$row-c$col';
}
