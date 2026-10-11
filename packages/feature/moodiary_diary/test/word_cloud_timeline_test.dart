import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_timeline.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 假度量：基准字号 64 下，每字 0.6 em 宽、行高 1 em。
Size _measure(String word) => Size(word.length * 0.6 * 64, 64);

WordCloudTerm _term(String word, List<int> buckets) => WordCloudTerm(
  word: word,
  total: buckets.fold(0, (sum, count) => sum + count),
  counts: buckets,
);

/// w0 累计 4、w1 累计 5、w2 累计 6（= 归一化基准）。
List<WordCloudTerm> _terms() => [
  _term('w0', [3, 0, 1]),
  _term('w1', [0, 5, 0]),
  _term('w2', [2, 2, 2]),
];

WordCloudTimeline _timeline(
  WordCloudPlayMode mode, {
  int from = 0,
  int to = 2,
  List<WordCloudTerm>? terms,
}) => WordCloudTimeline(
  terms: terms ?? _terms(),
  activeFirst: from,
  activeLast: to,
  mode: mode,
  size: const Size(320, 260),
  measure: _measure,
);

/// 造一份只关心窗口的 WordCloudData（吸附只跟窗口下标有关）。
WordCloudData _data(int windows) => WordCloudData(
  terms: [_term('w', List<int>.filled(windows, 1))],
  windows: [
    for (var i = 0; i < windows; i++)
      WordCloudWindow(
        start: DateTime(2026, 1 + i),
        endExclusive: DateTime(2026, 2 + i),
        partial: false,
      ),
  ],
  unit: WordCloudUnit.month,
  start: DateTime(2026),
  endExclusive: DateTime(2026, 1 + windows),
  diaryCount: windows,
  tokenCount: windows,
  activeFirst: 0,
  activeLast: windows - 1,
);

void main() {
  test('段数 = 播放窗口跨度；只有一个桶时也是 1', () {
    expect(_timeline(WordCloudPlayMode.perBucket).segments, 2);
    expect(_timeline(WordCloudPlayMode.perBucket, from: 1, to: 1).segments, 1);
    expect(_timeline(WordCloudPlayMode.perBucket, from: 1, to: 3).segments, 2);
  });

  test('逐期：这一段没出现的词在边界处字号归零，两端都没有就是 null', () {
    final timeline = _timeline(WordCloudPlayMode.perBucket);
    // w1（下标 1）只在第 1 段有词
    expect(timeline.at(1, 0)!.fontSize, closeTo(0, 1e-9));
    expect(timeline.at(1, 2), isNull);

    final mid = timeline.at(1, 1)!;
    expect(mid.fontSize, greaterThan(0));
    expect(mid.fontSize, lessThanOrEqualTo(44));
    // 从第 0 段过渡到第 1 段：字号边长大边长在原地（还没轮到它动）
    final half = timeline.at(1, 0.5)!;
    expect(half.fontSize, greaterThan(0));
    expect(half.fontSize, lessThan(mid.fontSize));
    expect(half.center, mid.center);
  });

  test('累计：播到末尾就是整区间词频，字号按全局基准比较', () {
    final timeline = _timeline(WordCloudPlayMode.cumulative);
    final w2 = timeline.at(2, 2)!; // 累计 6
    final w1 = timeline.at(1, 2)!; // 累计 5
    final w0 = timeline.at(0, 2)!; // 累计 4
    expect(w2.fontSize, greaterThan(w1.fontSize));
    expect(w1.fontSize, greaterThan(w0.fontSize));
    expect(w2.fontSize, closeTo(44, 1e-6)); // 归一化基准那一项拉满
  });

  test('相邻两段之间位置与字号线性插值', () {
    final timeline = _timeline(WordCloudPlayMode.perBucket);
    final a = timeline.at(2, 0)!;
    final b = timeline.at(2, 1)!;
    final mid = timeline.at(2, 0.5)!;
    expect(mid.center.dx, closeTo((a.center.dx + b.center.dx) / 2, 1e-9));
    expect(mid.center.dy, closeTo((a.center.dy + b.center.dy) / 2, 1e-9));
    expect(mid.fontSize, closeTo((a.fontSize + b.fontSize) / 2, 1e-9));
  });

  test('段是懒建的：用到哪段建哪段', () {
    final timeline = _timeline(WordCloudPlayMode.perBucket);
    expect(timeline.builtFrameCount, 0);
    // 一次插值要两端，所以第 0 段就建了 0 和 1
    timeline.at(0, 0);
    expect(timeline.builtFrameCount, 2);
    timeline.at(1, 2);
    expect(timeline.builtFrameCount, 3);
  });

  test('空词表、越界下标、越界位置都不炸', () {
    final empty = WordCloudTimeline(
      terms: const [],
      activeFirst: 0,
      activeLast: 3,
      mode: WordCloudPlayMode.perBucket,
      size: const Size(120, 120),
      measure: _measure,
    );
    expect(empty.at(0, 0), isNull);
    expect(empty.segments, 3);

    final timeline = _timeline(WordCloudPlayMode.perBucket);
    expect(timeline.at(-1, 0), isNull);
    expect(timeline.at(99, 0), isNull);
    // 位置超界会被夹回播放窗口
    expect(timeline.at(2, 99)!.center, timeline.at(2, 2)!.center);
    expect(timeline.at(2, -5)!.center, timeline.at(2, 0)!.center);
  });

  group('进度条吸附', () {
    test('落到最近的分割点，不停在两张中间', () {
      final data = _data(4); // 张号 0..3，段间隔 3
      // 进度 0.1 → 0.3 个张位，离第 0 张更近
      expect(data.snapToWindow(0.1), 0);
      // 进度 0.2 → 0.6 个张位，离第 1 张更近
      expect(data.snapToWindow(0.2), closeTo(1 / 3, 1e-9));
      // 已经在分割点上就不动
      expect(data.snapToWindow(2 / 3), closeTo(2 / 3, 1e-9));
      // 两端与越界
      expect(data.snapToWindow(0), 0);
      expect(data.snapToWindow(1), 1);
      expect(data.snapToWindow(-1), 0);
      expect(data.snapToWindow(9), 1);
    });

    test('正好在两张中间时按拖动方向取整', () {
      final data = _data(4);
      const half = 0.5 / 3; // 0.5 个张位
      expect(data.nearestWindowAt(half), 1); // 默认往前（右）
      expect(data.nearestWindowAt(half, forward: false), 0);
      expect(data.snapToWindow(half), closeTo(1 / 3, 1e-9));
      expect(data.snapToWindow(half, forward: false), 0);
      // 2.5 个张位：往前到 3，往回是 2
      expect(data.nearestWindowAt(2.5 / 3), 3);
      expect(data.nearestWindowAt(2.5 / 3, forward: false), 2);
    });

    test('只有一张时进度恒为 0，不炸', () {
      final data = _data(1);
      expect(data.segmentCount, 1);
      expect(data.activeWindowCount, 1);
      expect(data.snapToWindow(0.5), 0);
      expect(data.nearestWindowAt(0.5), 0);
    });

    test('吸附后的进度都落在整数张号上', () {
      final data = _data(7);
      for (var i = 0; i <= 100; i++) {
        final snapped = data.snapToWindow(i / 100);
        final position = data.windowPositionAt(snapped);
        expect(position, closeTo(position.roundToDouble(), 1e-9));
      }
    });
  });
}
