import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';

String sliceOf(String text, ChunkSpan s) =>
    text.substring(s.start, s.start + s.len);

void main() {
  test('空文本与纯空白无分块', () {
    expect(chunkOffsets(''), isEmpty);
    expect(chunkOffsets('\n\n  \n'), isEmpty);
  });

  test('短段落合并进同一块，偏移切回原文', () {
    const text = '第一段。\n\n第二段。';
    final spans = chunkOffsets(text, maxChars: 400);
    expect(spans, hasLength(1));
    expect(sliceOf(text, spans.single), contains('第一段。'));
    expect(sliceOf(text, spans.single), contains('第二段。'));
  });

  test('超过上限的段落进入新块', () {
    final a = 'a' * 300;
    final b = 'b' * 300;
    final text = '$a\n\n$b';
    final spans = chunkOffsets(text, maxChars: 400);
    expect(spans, hasLength(2));
    expect(sliceOf(text, spans[0]), a);
    expect(sliceOf(text, spans[1]), b);
  });

  test('超长单段硬切', () {
    final text = 'x' * 1000;
    final spans = chunkOffsets(text, maxChars: 400);
    expect(spans.map((s) => s.len), [400, 400, 200]);
    expect(
      spans.map((s) => sliceOf(text, s).length).reduce((a, b) => a + b),
      1000,
    );
  });

  test('段内换行不断块', () {
    const text = '第一行\n第二行\n第三行';
    final spans = chunkOffsets(text, maxChars: 400);
    expect(spans, hasLength(1));
    expect(sliceOf(text, spans.single), text);
  });
}
