import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

class FastTilePlanner {
  final Size imageSize;

  final int tileSize;

  final double cacheExtentScreens;

  final int maxVisibleTiles;

  final int maxPlannedTiles;

  const FastTilePlanner({
    required this.imageSize,
    this.tileSize = 512,
    this.cacheExtentScreens = 0.5,
    this.maxVisibleTiles = 96,
    this.maxPlannedTiles = 64,
  });

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

  final List<FastTileSpec> visible;

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

  final Rect sourceRect;

  const FastTileSpec({
    required this.sample,
    required this.row,
    required this.col,
    required this.sourceRect,
  });

  String get key => 's$sample-r$row-c$col';
}
