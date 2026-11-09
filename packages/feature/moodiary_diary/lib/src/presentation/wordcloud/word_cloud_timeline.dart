import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_layout.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 播放时的权重来源：逐期（只看当前窗口）或累计（从窗口起点累加）。
enum WordCloudPlayMode { perBucket, cumulative }

/// 按段摆放的时间轴：每一段一副独立的布局，播放时在相邻两段之间插值
/// **位置与字号**，所以词会随词频变化而重新排布，而不是钉在原地只改大小。
///
/// 段是懒构建的：用到哪段建哪段（一年 12 段、一个月 31 段、滑动窗口更多），
/// 每段一次摆放（毫秒级），所以既没有开场卡顿，也没有每帧重排。段缓存按
/// [WordCloudTerm] 的下标对齐，插值就是同一下标取两端。
///
/// 窗口长度 W 与步长 Δ 只影响 `WordCloudData.windows` 和每个词的 counts，
/// 这里只按窗口下标工作，所以滑动/不重叠两种模式共用同一套播放逻辑。
class WordCloudTimeline {
  WordCloudTimeline({
    required this.terms,
    required this.activeFirst,
    required this.activeLast,
    required this.mode,
    required this.size,
    required this.measure,
    this.baseFontSize = 64,
    this.minFontSize = 12,
    this.maxFontSize = 44,
  }) : normalizeWeight = _maxTotal(terms);

  final List<WordCloudTerm> terms;

  /// 播放窗口（含），来自 `WordCloudData.activeFirst/activeLast`。
  final int activeFirst;
  final int activeLast;

  final WordCloudPlayMode mode;
  final Size size;

  /// 在 [baseFontSize] 下量一个词（调用方缓存）。
  final Size Function(String word) measure;

  final double baseFontSize;
  final double minFontSize;
  final double maxFontSize;

  /// 字号归一化基准：整区间最大词频，各段可比。
  final double normalizeWeight;

  final Map<int, List<PlacedWord?>> _frames = {};

  static double _maxTotal(List<WordCloudTerm> terms) {
    var max = 0;
    for (final term in terms) {
      if (term.total > max) max = term.total;
    }
    return max <= 0 ? 1.0 : max.toDouble();
  }

  /// 段数：至少 1（只有一个窗口时没有可插值的下一段）。
  int get segments => activeLast > activeFirst ? activeLast - activeFirst : 1;

  int _windowOf(int step) => math.min(activeFirst + step, activeLast);

  int _weightOf(WordCloudTerm term, int window) => switch (mode) {
    WordCloudPlayMode.perBucket => term.countAt(window),
    WordCloudPlayMode.cumulative => term.cumulativeAt(window),
  };

  /// 第 [step] 段的摆放；权重为 0 的词不进这一段（也就是"不在这一帧"）。
  List<PlacedWord?> _frameAt(int step) {
    final clamped = step.clamp(0, segments);
    return _frames.putIfAbsent(clamped, () {
      final window = _windowOf(clamped);
      final weighted = <({String word, int weight})>[];
      for (final term in terms) {
        final weight = _weightOf(term, window);
        if (weight > 0) weighted.add((word: term.word, weight: weight));
      }
      final layout = WordCloudLayout.build(
        terms: weighted,
        size: size,
        measure: measure,
        normalizeWeight: normalizeWeight,
        baseFontSize: baseFontSize,
        minFontSize: minFontSize,
        maxFontSize: maxFontSize,
      );
      final byWord = {for (final word in layout.words) word.word: word};
      return [for (final term in terms) byWord[term.word]];
    });
  }

  /// 已构建的段数（测试与性能观察用）。
  int get builtFrameCount => _frames.length;

  /// 先把某一段的摆放算好：段边界上就不会现算而掉一帧。
  void prebuild(int step) => _frameAt(step);

  /// 浮点段号 [position]（0..[segments]）处第 [index] 个词的样子。
  ///
  /// 只在某一端存在时，它从/向 0 字号在原地长出来或缩回去。
  PlacedWord? at(int index, double position) {
    if (index < 0 || index >= terms.length) return null;
    final clamped = position.clamp(0.0, segments.toDouble());
    final step = clamped.floor().clamp(0, segments);
    final frac = clamped - step;
    final a = _frameAt(step)[index];
    final b = _frameAt(math.min(step + 1, segments))[index];
    if (a == null && b == null) return null;
    final term = terms[index];
    if (a == null) {
      return PlacedWord(
        word: b!.word,
        weight: term.total,
        fontSize: b.fontSize * frac,
        center: b.center,
        size: Size(b.size.width * frac, b.size.height * frac),
      );
    }
    if (b == null) {
      final fade = 1 - frac;
      return PlacedWord(
        word: a.word,
        weight: term.total,
        fontSize: a.fontSize * fade,
        center: a.center,
        size: Size(a.size.width * fade, a.size.height * fade),
      );
    }
    return PlacedWord(
      word: a.word,
      weight: term.total,
      fontSize: a.fontSize + (b.fontSize - a.fontSize) * frac,
      center: Offset.lerp(a.center, b.center, frac)!,
      size: Size(
        a.size.width + (b.size.width - a.size.width) * frac,
        a.size.height + (b.size.height - a.size.height) * frac,
      ),
    );
  }
}
