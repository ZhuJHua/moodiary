import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  testWidgets(
    'caret uses the insertion font ascent/descent around the actual baseline',
    (tester) async {
      final schema = ft.Schema.standard();
      const base = TextStyle(
        fontFamily: '.AppleSystemUIFont',
        fontSize: 17,
        height: 1.75,
      );
      const large = TextStyle(fontSize: 32);
      const style = ft.TiptapEditorStyle(
        paragraph: base,
        marks: {'bold': large},
      );
      final cases = <(String, String, List<ft.Node>)>[
        (
          'paragraph',
          'English hgj',
          [schema.node('text', text: 'English hgj')],
        ),
        ('paragraph', '中文日记', [schema.node('text', text: '中文日记')]),
        ('heading', 'Heading hgj', [schema.node('text', text: 'Heading hgj')]),
        ('codeBlock', 'code hgj', [schema.node('text', text: 'code hgj')]),
        ('paragraph', '', []),
        ('heading', '', []),
        ('codeBlock', '', []),
        ('paragraph', 'line\n', [schema.node('text', text: 'line\n')]),
        (
          'paragraph',
          'big small',
          [
            schema.node('text', text: 'big', marks: [schema.mark('bold')]),
            schema.node('text', text: ' small'),
          ],
        ),
        (
          'paragraph',
          'small big',
          [
            schema.node('text', text: 'small '),
            schema.node('text', text: 'big', marks: [schema.mark('bold')]),
          ],
        ),
      ];
      for (final (type, text, content) in cases) {
        final node = schema.node(
          type,
          attrs: type == 'heading' ? {'level': 2} : null,
          content: content,
        );
        final controller = ft.TiptapController(
          doc: schema.node('doc', content: [node]),
        );
        final focus = FocusNode();
        final key = GlobalKey<ft.TiptapEditorState>();
        await tester.pumpWidget(
          CupertinoApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              focusNode: focus,
              style: style,
            ),
          ),
        );
        focus.requestFocus();
        controller.setSelection(ft.TextSelection(text.length + 1));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final blockStyle = style.forBlock(node);
        final reference = TextPainter(
          text: TextSpan(
            style: blockStyle,
            children: [
              if (text.isEmpty) const TextSpan(text: '\u200b'),
              for (final inline in content)
                TextSpan(
                  text: inline.text,
                  style: style.forInline(inline, blockStyle),
                ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 768);
        final line = reference.computeLineMetrics().last;
        final insertionStyle = content.isEmpty || text.endsWith('\n')
            ? blockStyle
            : style.forInline(content.last, blockStyle);
        final sample = text.isEmpty || text.endsWith('\n')
            ? ' '
            : text.characters.last;
        final natural = TextPainter(
          text: TextSpan(
            text: sample,
            style: insertionStyle.copyWith(height: kTextHeightNone),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final font = natural.computeLineMetrics().first;
        final actual = key.currentState!.debugCaretMetrics!;
        final baseline = 16 + (type == 'codeBlock' ? 28 : 0) + line.baseline;
        expect(actual.baseline, closeTo(baseline, .01), reason: '$type: $text');
        expect(
          actual.rect.top,
          closeTo(baseline - font.ascent, .01),
          reason: '$type: $text top',
        );
        expect(
          actual.rect.bottom,
          closeTo(baseline + font.descent, .01),
          reason: '$type: $text bottom',
        );
        expect(actual.rect.bottom, greaterThan(actual.baseline));
        expect(
          key.currentState!.debugCaret.rect!.top,
          closeTo(actual.rect.top, .01),
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              focusNode: focus,
              style: const ft.TiptapEditorStyle(
                paragraph: base,
                marks: {'bold': large},
                caretHeightFactor: 1.5,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final scaled = key.currentState!.debugCaretMetrics!;
        final extra = (font.ascent + font.descent) * .25;
        expect(scaled.baseline, closeTo(baseline, .01));
        expect(scaled.rect.top, closeTo(actual.rect.top - extra, .01));
        expect(scaled.rect.bottom, closeTo(actual.rect.bottom + extra, .01));
        reference.dispose();
        natural.dispose();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        focus.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
