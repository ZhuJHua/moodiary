import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_layout.dart';

/// 假度量：基准字号 64 下，每字 0.6 em 宽、行高 1 em。
Size _measure(String word) => Size(word.length * 0.6 * 64, 64);

List<({String word, int weight})> _terms(int count) => [
  for (var i = 0; i < count; i++)
    (word: '${'w' * (2 + i % 4)}$i', weight: count - i),
];

void _expectInside(WordCloudLayout layout, Size size) {
  for (final w in layout.words) {
    final r = w.bounds;
    expect(
      r.left >= 0 &&
          r.top >= 0 &&
          r.right <= size.width &&
          r.bottom <= size.height,
      isTrue,
      reason: '${w.word} 越界：$r / $size',
    );
  }
}

void main() {
  const size = Size(360, 320);

  test('摆好的词互不重叠且都在画布内', () {
    final layout = WordCloudLayout.build(
      terms: _terms(40),
      size: size,
      measure: _measure,
    );

    expect(layout.words, isNotEmpty);
    expect(layout.maxWeight, 40);
    _expectInside(layout, size);

    for (var i = 0; i < layout.words.length; i++) {
      for (var j = i + 1; j < layout.words.length; j++) {
        expect(
          layout.words[i].bounds.overlaps(layout.words[j].bounds),
          isFalse,
          reason: '${layout.words[i].word} 与 ${layout.words[j].word} 重叠',
        );
      }
    }
  });

  test('同输入同输出（布局确定，重开页面不会重排）', () {
    final a = WordCloudLayout.build(
      terms: _terms(30),
      size: size,
      measure: _measure,
    );
    final b = WordCloudLayout.build(
      terms: _terms(30),
      size: size,
      measure: _measure,
    );

    expect(a.words.length, b.words.length);
    for (var i = 0; i < a.words.length; i++) {
      expect(a.words[i].word, b.words[i].word);
      expect(a.words[i].center, b.words[i].center);
      expect(a.words[i].fontSize, b.words[i].fontSize);
    }
  });

  test('按词频降序摆放，字号单调不增且落在区间内', () {
    final layout = WordCloudLayout.build(
      terms: _terms(20),
      size: size,
      measure: _measure,
    );

    for (var i = 0; i < layout.words.length; i++) {
      final w = layout.words[i];
      expect(w.fontSize, greaterThanOrEqualTo(12));
      expect(w.fontSize, lessThanOrEqualTo(44));
      if (i > 0) {
        expect(w.weight, lessThanOrEqualTo(layout.words[i - 1].weight));
        expect(
          w.fontSize,
          lessThanOrEqualTo(layout.words[i - 1].fontSize + 1e-9),
        );
      }
    }
    expect(layout.words.first.word, 'ww0');
  });

  test('画布太小就丢掉装不下的词，剩下的仍然不越界', () {
    const small = Size(80, 80);
    final layout = WordCloudLayout.build(
      terms: _terms(60),
      size: small,
      measure: _measure,
    );

    expect(layout.words, isNotEmpty);
    expect(layout.words.length, lessThan(60));
    _expectInside(layout, small);
  });

  test('归一化基准可以由外部指定（播放时各段字号才可比）', () {
    final batch = WordCloudLayout.build(
      terms: _terms(6),
      size: size,
      measure: _measure,
    );
    // 同一批词，基准放大 4 倍 → 每个词都明显变小，但仍然 ≥ 最小字号
    final scaled = WordCloudLayout.build(
      terms: _terms(6),
      size: size,
      measure: _measure,
      normalizeWeight: batch.maxWeight * 4,
    );

    expect(scaled.words.map((w) => w.word), batch.words.map((w) => w.word));
    for (var i = 0; i < batch.words.length; i++) {
      expect(scaled.words[i].fontSize, lessThan(batch.words[i].fontSize));
      expect(scaled.words[i].fontSize, greaterThanOrEqualTo(12));
    }
  });

  test('空输入与空画布', () {
    expect(
      WordCloudLayout.build(
        terms: const [],
        size: size,
        measure: _measure,
      ).isEmpty,
      isTrue,
    );
    expect(
      WordCloudLayout.build(
        terms: _terms(3),
        size: Size.zero,
        measure: _measure,
      ).isEmpty,
      isTrue,
    );
  });
}
