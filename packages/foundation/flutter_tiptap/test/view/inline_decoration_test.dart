import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

Future<Rect> _ink(GlobalKey key, bool Function(int, int, int) match) async {
  final image =
      await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
          .toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  var left = image.width, top = image.height, right = 0, bottom = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final at = (y * image.width + x) * 4;
      if (match(bytes[at], bytes[at + 1], bytes[at + 2])) {
        if (x < left) left = x;
        if (y < top) top = y;
        if (x + 1 > right) right = x + 1;
        if (y + 1 > bottom) bottom = y + 1;
      }
    }
  }
  image.dispose();
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

void main() {
  final schema = ft.Schema.standard();
  const green = Color(0xff00ff00), red = Color(0xffff0000);
  testWidgets(
    'inline code padding preserves model positions, mono advances and line height',
    (tester) async {
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node(
              'paragraph',
              content: [
                schema.node('text', text: 'X '),
                schema.node(
                  'text',
                  text: 'inline code',
                  marks: [schema.mark('code')],
                ),
                schema.node('text', text: ' tail'),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>();
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: true,
            style: const ft.TiptapEditorStyle(
              exactLineHeight: true,
              paragraph: TextStyle(fontSize: 17, height: 1.75),
              marks: {
                'code': TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 0,
                  backgroundColor: Color(0xffeeeeee),
                ),
              },
              inlineCodeFontSizeFactor: .875,
              inlineCodePadding: Offset(.35, .1),
              inlineCodeRadius: 4,
            ),
          ),
        ),
      );
      await tester.pump();
      final geometry = key.currentState!.geometry!;
      expect(geometry.rowRect(0).height, closeTo(29.75, .01));
      for (var at = 1; at <= 18; at++) {
        final rect = geometry.caretRect(at);
        expect(
          geometry.positionForOffset(Offset(rect.left + .01, rect.center.dy)),
          at,
          reason: 'Padding must not become a document character at $at',
        );
      }
      final step = geometry.caretRect(5).left - geometry.caretRect(4).left;
      for (var at = 4; at < 13; at++) {
        expect(
          geometry.caretRect(at + 1).left - geometry.caretRect(at).left,
          closeTo(step, .01),
          reason: 'Code spaces use the same monospace advance',
        );
      }
      expect(geometry.wordBoundary(5), const TextRange(start: 3, end: 9));
      expect(controller.state.doc.textContent, 'X inline code tail');
    },
  );

  testWidgets('reference chip glyphs share the surrounding text baseline', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              schema.node('text', text: 'ghj '),
              schema.node('diaryLink', attrs: {'id': '1', 'label': 'ghj'}),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: RepaintBoundary(
          key: boundary,
          child: ft.TiptapEditor(
            controller: controller,
            readOnly: true,
            style: const ft.TiptapEditorStyle(
              exactLineHeight: true,
              paragraph: TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                height: 1.75,
                color: green,
              ),
              reference: TextStyle(color: red),
              referencePadding: 4,
              referenceRadius: 6,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final inks = await tester.runAsync(
      () async => [
        await _ink(boundary, (r, g, b) => g > 220 && r < 30 && b < 30),
        await _ink(boundary, (r, g, b) => r > 220 && g < 30 && b < 30),
      ],
    );
    expect(
      inks![1].top,
      closeTo(inks[0].top, 1),
      reason: 'Fractional glyph rasterization may differ by one pixel',
    );
    expect(inks[1].bottom, closeTo(inks[0].bottom, 1));
  });

  testWidgets('unchecked task border stays inside its border box', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'taskList',
            content: [
              schema.node('taskItem', content: [schema.node('paragraph')]),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: RepaintBoundary(
          key: boundary,
          child: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: true,
            style: const ft.TiptapEditorStyle(markerColor: red),
          ),
        ),
      ),
    );
    await tester.pump();
    final rect = key.currentState!.geometry!.taskCheckboxRect(2)!;
    final ink = await tester.runAsync(
      () => _ink(boundary, (r, g, b) => r > 220 && g < 30 && b < 30),
    );
    expect(ink!.left, greaterThanOrEqualTo(rect.left.floorToDouble()));
    expect(ink.right, lessThanOrEqualTo(rect.right.ceilToDouble()));
  });
}
