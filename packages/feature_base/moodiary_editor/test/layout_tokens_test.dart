import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:mui/mui.dart';

void main() {
  final schema = ft.Schema.standard();
  ft.Node node(String type, [Map<String, Object?>? attrs]) =>
      schema.node(type, attrs: attrs);

  test('code surface and inline decoration tokens remain stable', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final style = buildEditorStyle(
      colors: const ColorScheme.light(
        surfaceContainer: Color(0xff112233),
        surfaceContainerHigh: Color(0xff445566),
      ),
      brightness: Brightness.light,
    );
    expect(style.codeBackground.toARGB32(), 0xff112233);
    expect(style.marks['code']!.backgroundColor!.toARGB32(), 0xff445566);
    expect(style.inlineCodePadding, const Offset(.35, .1));
    expect(style.inlineCodeRadius, 4);
    expect(style.highlightPadding, 1);
    expect(style.highlightRadius, 3);
    expect(style.highlightHeight!(16.1865, 4.1006), 22);
    expect(style.paragraph.leadingDistribution, TextLeadingDistribution.even);
    expect(
      style.headings.first.leadingDistribution,
      TextLeadingDistribution.even,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      buildEditorStyle(brightness: Brightness.light).highlightHeight,
      isNull,
    );
    expect(style.inlineCodeFontSizeFactor, .875);
    expect(style.marks['code']!.fontFamily, '.AppleSystemUIFontMonospaced');
    expect(style.codeBlock.fontFamily, '.AppleSystemUIFontMonospaced');
  });

  test('collapsed margins remain pinned to the document layout tokens', () {
    const font = 1.0, spacing = 1.0;
    final style = buildEditorStyle(brightness: Brightness.light);
    final body = 17 * font, gap = style.blockGap!;
    expect(style.exactLineHeight, true);
    expect(gap(null, node('image')), body * .75 * spacing);
    expect(gap(node('image'), node('paragraph')), body * .75 * spacing);
    expect(gap(node('paragraph'), node('paragraph')), body * .75 * spacing);
    expect(style.blockSpacing, body * .75 * spacing);
    expect(
      gap(node('heading', {'level': 2}), node('image')),
      body * .75 * spacing,
    );
    expect(
      gap(node('paragraph'), node('heading', {'level': 2})),
      body * 1.25 * 1.4 * spacing,
    );
    expect(
      gap(node('heading', {'level': 1}), node('heading', {'level': 2})),
      body * 1.25 * .4 * spacing,
    );
    expect(gap(node('paragraph'), node('table')), body * .75 * spacing);
    expect(
      gap(node('horizontalRule', {'variant': 'text'}), node('table')),
      (13 > body * .75 ? 13 : body * .75) * spacing,
    );
    expect(gap(node('paragraph'), null), 0);
    expect(style.cellBlockGap!(node('paragraph'), node('paragraph')), 0);
    expect(
      style.cellBlockGap!(node('paragraph'), node('image')),
      body * .75 * spacing,
    );
    expect(style.taskIndent, body * 1.2 + 10);
    expect(style.taskMinHeight, body * (1.2 + .275));
    expect(style.nestedTaskIndent, body * .2);
    expect(style.codeBlock.fontSize, 14);
    expect(style.codeBlockPadding.top, 4 + 28 + 6);
    expect(style.ruleHeights!['solid'], body + 1);
    expect(style.ruleHeights!['wavy'], body + 6);
    expect(style.ruleHeights!['text'], 13 * 2.4);
  });
  test(
    'SF tracking does not compress fallback CJK runs at maximum font size',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final style = buildEditorStyle(
        brightness: Brightness.light,
        fontScale: 1.3,
      );
      const text = 'B03 中文段落：字，Ａ。 한글𠀀 end';
      final runs = style.textRuns!(text, style.paragraph).toList();
      expect(runs.map((r) => r.$1).join(), text);
      expect(runs.first.$2.letterSpacing, lessThan(0));
      expect(runs.where((r) => r.$1.contains('中文')).single.$2.letterSpacing, 0);
      expect(runs.where((r) => r.$1.contains('𠀀')).single.$2.letterSpacing, 0);
      final code = style.paragraph.merge(style.marks['code']);
      expect(style.textRuns!('code中文', code).single.$2, code);
    },
  );
}
