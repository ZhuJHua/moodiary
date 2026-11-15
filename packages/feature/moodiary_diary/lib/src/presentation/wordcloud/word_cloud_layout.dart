import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// 一个摆好的词。
class PlacedWord {
  final String word;

  /// 整区间词频，用于颜色深浅等映射。
  final int weight;

  final double fontSize;

  /// 文字中心（画布坐标）。
  final Offset center;

  /// 文字自身的尺寸，不含摆放时预留的间隙。
  final Size size;

  const PlacedWord({
    required this.word,
    required this.weight,
    required this.fontSize,
    required this.center,
    required this.size,
  });

  Rect get bounds =>
      Rect.fromCenter(center: center, width: size.width, height: size.height);
}

/// 词云的摆放结果。**纯 Dart、无 dart:ui 依赖才能单测** —— 文字度量由调用方
/// 以 [WordCloudLayout.build] 的 `measure` 参数注入。
///
/// 摆放只做一次（用整区间词频），播放时只改字号与透明度：这样每帧没有重排、
/// 词的位置也不会跳。代价是当前桶没出现的词会以 0 字号占位（不可见）。
class WordCloudLayout {
  final List<PlacedWord> words;

  /// 参与摆放的最大词频，调用方用它把字号/颜色归一化。
  final int maxWeight;

  const WordCloudLayout({required this.words, required this.maxWeight});

  static const WordCloudLayout empty = WordCloudLayout(words: [], maxWeight: 0);

  bool get isEmpty => words.isEmpty;

  /// [measure] 在 [baseFontSize] 下量一次词宽高；摆放按字号线性缩放，
  /// 所以每个词只需要量一次（缓存由调用方负责）。
  ///
  /// [normalizeWeight] 是字号归一化的基准，默认取本批词的最大词频。播放时
  /// 要传整区间的最大词频，各段的字号才可比（否则每个稀疏段都会被拉满）。
  ///
  /// 装不下的词直接丢弃，不缩小字号硬塞 —— 否则 [maxFontSize] 就没有意义了。
  static WordCloudLayout build({
    required List<({String word, int weight})> terms,
    required Size size,
    required Size Function(String word) measure,
    double? normalizeWeight,
    double baseFontSize = 64,
    double minFontSize = 12,
    double maxFontSize = 44,
    double gap = 3,
    double margin = 4,
  }) {
    if (terms.isEmpty || size.isEmpty || baseFontSize <= 0) {
      return empty;
    }
    final sorted = [...terms]
      ..sort((a, b) {
        final byWeight = b.weight.compareTo(a.weight);
        return byWeight != 0 ? byWeight : a.word.compareTo(b.word);
      });
    final maxWeight = sorted.first.weight;
    final normalize = normalizeWeight != null && normalizeWeight > 0
        ? normalizeWeight
        : maxWeight.toDouble();

    // 径向间距 ≈ 最小字号，弧向步长略小：既能塞进最小的词，候选点又不过密。
    final pitch = math.max(8.0, minFontSize * 0.9);
    final arcStep = math.max(6.0, minFontSize * 0.8);
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.62;
    final maxRing = (maxRadius / pitch).ceil();
    final grid = _OccupancyGrid(size, math.max(8.0, minFontSize));

    final placed = <PlacedWord>[];
    for (final term in sorted) {
      final ratio = (term.weight / normalize).clamp(0.0, 1.0);
      final fontSize =
          minFontSize +
          (maxFontSize - minFontSize) * math.pow(ratio, 0.6).toDouble();
      final scale = fontSize / baseFontSize;
      final raw = measure(term.word);
      final textSize = Size(raw.width * scale, raw.height * scale);
      if (textSize.width <= 0 || textSize.height <= 0) continue;

      final hit = grid.find(
        textSize: textSize,
        gap: gap,
        margin: margin,
        center: center,
        pitch: pitch,
        arcStep: arcStep,
        maxRing: maxRing,
      );
      if (hit == null) continue;

      final word = PlacedWord(
        word: term.word,
        weight: term.weight,
        fontSize: fontSize,
        center: hit,
        size: textSize,
      );
      placed.add(word);
      grid.occupy(word.bounds.inflate(gap));
    }
    return WordCloudLayout(words: placed, maxWeight: maxWeight);
  }
}

/// 均匀网格占用表：格子按尺寸分桶，候选矩形只跟同格子的词比。
///
/// 与 graph_canvas.dart 的标签避让同一套思路（把二维格子折成一个 int），
/// 那里是"撞了就跳过"，这里是螺线搜索的第一个空位。
class _OccupancyGrid {
  _OccupancyGrid(Size canvas, double cellSize)
    : size = canvas,
      cell = cellSize,
      cols = math.max(1, (canvas.width / cellSize).ceil()),
      rows = math.max(1, (canvas.height / cellSize).ceil()),
      cells = List.generate(
        math.max(1, (canvas.width / cellSize).ceil()) *
            math.max(1, (canvas.height / cellSize).ceil()),
        (_) => <Rect>[],
      );

  final Size size;
  final double cell;
  final int cols;
  final int rows;
  final List<List<Rect>> cells;

  void occupy(Rect rect) {
    final (c0, r0, c1, r1) = _range(rect);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        cells[r * cols + c].add(rect);
      }
    }
  }

  bool isFree(Rect rect) {
    if (rect.left < 0 ||
        rect.top < 0 ||
        rect.right > size.width ||
        rect.bottom > size.height) {
      return false;
    }
    final (c0, r0, c1, r1) = _range(rect);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        for (final other in cells[r * cols + c]) {
          if (other.overlaps(rect)) return false;
        }
      }
    }
    return true;
  }

  /// 从中心向外按环扫描，返回第一个放得下的中心点；放不下返回 null。
  Offset? find({
    required Size textSize,
    required double gap,
    required double margin,
    required Offset center,
    required double pitch,
    required double arcStep,
    required int maxRing,
  }) {
    final half = Size(textSize.width / 2, textSize.height / 2);
    bool fits(Offset at) {
      final rect = Rect.fromCenter(
        center: at,
        width: textSize.width,
        height: textSize.height,
      ).inflate(gap);
      if (margin > 0) {
        if (rect.left < margin ||
            rect.top < margin ||
            rect.right > size.width - margin ||
            rect.bottom > size.height - margin) {
          return false;
        }
      }
      return isFree(rect);
    }

    if (fits(center)) return center;
    for (var ring = 1; ring <= maxRing; ring++) {
      final radius = ring * pitch;
      // 环上交错相位，避免所有环的候选点连成辐条。
      final phase = ring * 0.7;
      final count = math.max(6, (2 * math.pi * radius / arcStep).ceil());
      for (var i = 0; i < count; i++) {
        final angle = phase + 2 * math.pi * i / count;
        final at = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        // 快速排除：中心离得太远时整个矩形都在画布外。
        if (at.dx + half.width < 0 ||
            at.dy + half.height < 0 ||
            at.dx - half.width > size.width ||
            at.dy - half.height > size.height) {
          continue;
        }
        if (fits(at)) return at;
      }
    }
    return null;
  }

  (int, int, int, int) _range(Rect rect) => (
    (rect.left / cell).floor().clamp(0, cols - 1),
    (rect.top / cell).floor().clamp(0, rows - 1),
    (rect.right / cell).floor().clamp(0, cols - 1),
    (rect.bottom / cell).floor().clamp(0, rows - 1),
  );
}
