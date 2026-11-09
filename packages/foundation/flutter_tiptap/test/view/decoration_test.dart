import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

class _Pixels {
  _Pixels(this.image, this.bytes, this.scale);
  final ui.Image image;
  final ByteData bytes;
  final double scale;
  bool red(int x, int y) {
    final i = (y * image.width + x) * 4;
    return bytes.getUint8(i) > 220 &&
        bytes.getUint8(i + 1) < 30 &&
        bytes.getUint8(i + 2) < 30;
  }

  List<int> column(double x) => [
    for (var y = 0; y < image.height; y++)
      if (red((x * scale).floor(), y)) y,
  ];
  double thickness(double x) {
    var coverage = 0.0;
    for (var y = 0; y < image.height; y++) {
      final i = (y * image.width + (x * scale).floor()) * 4;
      final red = bytes.getUint8(i) - bytes.getUint8(i + 1);
      if (red > 0) coverage += red / 255 * bytes.getUint8(i + 3) / 255;
    }
    return coverage / scale;
  }

  bool at(double x, double y) => red((x * scale).floor(), (y * scale).floor());
  Rect get bounds {
    var l = image.width, r = 0, t = image.height, b = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (!red(x, y)) continue;
        l = x < l ? x : l;
        r = x + 1 > r ? x + 1 : r;
        t = y < t ? y : t;
        b = y + 1 > b ? y + 1 : b;
      }
    }
    return Rect.fromLTRB(l / scale, t / scale, r / scale, b / scale);
  }
}

Future<_Pixels> _pixels(GlobalKey key, WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 4);
      return _Pixels(
        image,
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
        4,
      );
    }))!;

void main() {
  final schema = ft.Schema.standard();
  const red = Color(0xffff0000), black = Color(0xff000000);
  ft.Node p(String text) =>
      schema.node('paragraph', content: [schema.node('text', text: text)]);
  Future<void> mount(
    WidgetTester tester,
    ft.TiptapController controller,
    GlobalKey<ft.TiptapEditorState> key,
    GlobalKey boundary,
    ft.TiptapEditorStyle style, {
    double width = 500,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 500,
            child: RepaintBoundary(
              key: boundary,
              child: ft.TiptapEditor(
                key: key,
                controller: controller,
                readOnly: true,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'highlight has two padding pixels per mark, half-leading and rounded corners',
    (tester) async {
      final highlighted = schema.node(
        'paragraph',
        content: [
          schema.node('text', text: 'X '),
          schema.node('text', text: 'gh', marks: [schema.mark('highlight')]),
          schema.node(
            'text',
            text: 'j',
            marks: [schema.mark('highlight'), schema.mark('bold')],
          ),
          schema.node('text', text: ' T'),
        ],
      );
      final plain = p('X ghj T');
      final controller = ft.TiptapController(
        doc: schema.node('doc', content: [highlighted, plain]),
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
      await mount(
        tester,
        controller,
        key,
        boundary,
        const ft.TiptapEditorStyle(
          exactLineHeight: true,
          paragraph: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 17,
            height: 1.75,
            color: Color(0x00000000),
          ),
          highlightPadding: 1,
          highlightRadius: 3,
          marks: {
            'highlight': TextStyle(backgroundColor: red),
            'bold': TextStyle(fontWeight: FontWeight.w700),
          },
        ),
      );
      final g = key.currentState!.geometry!, caret = g.caretRect(3);
      expect(g.rowRect(0).height, closeTo(29.75, .01));
      expect(
        g.caretRect(8).left - g.caretRect(highlighted.nodeSize + 8).left,
        closeTo(2, .01),
      );
      for (var at = 1; at <= 8; at++) {
        final c = g.caretRect(at);
        expect(g.positionForOffset(Offset(c.left + .01, c.center.dy)), at);
      }
      expect(controller.state.doc.textContent, 'X ghj TX ghj T');
      final pixels = await _pixels(boundary, tester);
      addTearDown(pixels.image.dispose);
      final ink = pixels.bounds;
      expect(ink.left, closeTo(caret.left - 1, .25));
      expect(ink.right, closeTo(g.caretRect(6).left, .25));
      const referenceStyle = TextStyle(
        fontFamily: 'Ahem',
        fontSize: 17,
        height: 1.75,
      );
      final natural = TextPainter(
        text: TextSpan(
          text: 'hgj',
          style: referenceStyle.copyWith(height: ui.kTextHeightNone),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final metrics = natural.computeLineMetrics().first;
      final height = metrics.ascent + metrics.descent;
      final top = g.rowRect(0).top + (g.rowRect(0).height - height) / 2;
      expect(ink.top, closeTo(top, .5));
      expect(ink.bottom, closeTo(top + height, .5));
      natural.dispose();
      expect(ink.height, lessThan(g.rowRect(0).height - 5));
      expect(pixels.at(ink.left + .25, ink.top + .25), false);
      expect(pixels.at(ink.left + 4, ink.top + .25), true);
    },
  );

  testWidgets('rounded font boxes preserve glyph and caret geometry', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              schema.node(
                'text',
                text: 'ghj',
                marks: [schema.mark('highlight')],
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
    for (final leading in [1.2, 1.75, 2.1]) {
      ft.TiptapEditorStyle style(bool rounded) => ft.TiptapEditorStyle(
        exactLineHeight: true,
        paragraph: TextStyle(
          fontFamily: 'Ahem',
          fontSize: 17,
          height: leading,
          color: const Color(0x00000000),
        ),
        highlightPadding: 1,
        highlightRadius: 3,
        highlightHeight: rounded
            ? (ascent, descent) =>
                  ascent.ceilToDouble() + descent.ceilToDouble()
            : null,
        marks: const {'highlight': TextStyle(backgroundColor: red)},
      );
      await mount(tester, controller, key, boundary, style(false));
      final caret = key.currentState!.geometry!.caretRect(3);
      await mount(tester, controller, key, boundary, style(true));
      final geometry = key.currentState!.geometry!;
      expect(geometry.caretRect(3), caret);
      final pixels = await _pixels(boundary, tester);
      final row = geometry.rowRect(0);
      // Ahem's natural 13.6/3.4 ascent/descent round up to a 14+4 px box.
      expect(
        pixels.bounds.top,
        closeTo(row.top + (17 * leading - 18) / 2, .25),
      );
      expect(pixels.bounds.height, closeTo(18, .5));
      expect(row.height, closeTo(17 * leading, .01));
      pixels.image.dispose();
    }
  });

  testWidgets(
    'wrapped highlighted fragments leave leading clear and preserve model boundaries',
    (tester) async {
      final text = 'ghj ' * 8;
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node(
              'paragraph',
              content: [
                schema.node(
                  'text',
                  text: text,
                  marks: [schema.mark('highlight')],
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
      await mount(
        tester,
        controller,
        key,
        boundary,
        const ft.TiptapEditorStyle(
          exactLineHeight: true,
          paragraph: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 17,
            height: 1.75,
            color: Color(0x00000000),
          ),
          highlightPadding: 1,
          highlightRadius: 3,
          marks: {'highlight': TextStyle(backgroundColor: red)},
        ),
        width: 150,
      );
      final g = key.currentState!.geometry!;
      final pixels = await _pixels(boundary, tester);
      addTearDown(pixels.image.dispose);
      final first = g.caretRect(1),
          second = g.caretRect(g.lineBoundary(1).end + 1);
      expect(second.top, greaterThan(first.top));
      expect(pixels.at(first.left + 4, (first.bottom + second.top) / 2), false);
      expect(controller.state.doc.textContent, text);
      expect(
        g.rowRect(0).height / 29.75,
        closeTo((g.rowRect(0).height / 29.75).round(), .01),
      );
    },
  );

  testWidgets(
    'quote bars bridge only internal gaps, including nested and adjacent quotes',
    (tester) async {
      final first = schema.node(
        'blockquote',
        content: [
          p('A'),
          schema.node('blockquote', content: [p('B')]),
          p('C'),
        ],
      );
      final second = schema.node('blockquote', content: [p('D')]);
      final controller = ft.TiptapController(
        doc: schema.node('doc', content: [first, second, p('Z')]),
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
      await mount(
        tester,
        controller,
        key,
        boundary,
        const ft.TiptapEditorStyle(
          exactLineHeight: true,
          paragraph: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 17,
            height: 1.75,
            color: black,
          ),
          quoteBorderColor: red,
          blockSpacing: 17,
        ),
      );
      final g = key.currentState!.geometry!;
      final a = g.rowRect(1), b = g.rowRect(5), c = g.rowRect(9);
      final d = g.rowRect(first.nodeSize + 1);
      final pixels = await _pixels(boundary, tester);
      addTearDown(pixels.image.dispose);
      expect(pixels.at(18, a.top + 1), true);
      expect(
        pixels.at(18, b.bottom + 8),
        true,
        reason: 'Outer quote includes its internal paragraph gap',
      );
      expect(
        pixels.at(39, b.bottom + 8),
        false,
        reason: 'Inner quote stops at its last line',
      );
      expect(
        pixels.at(18, c.bottom + 8),
        false,
        reason: 'Gap before a separate quote belongs outside both bars',
      );
      expect(pixels.at(18, d.bottom + 8), false);
      expect(pixels.column(18).last / 4, closeTo(d.bottom, .3));
    },
  );

  testWidgets('wavy rule has a 12 by 6 wave, 1.3 stroke and foreground color', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node('horizontalRule', attrs: {'variant': 'wavy'}),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = GlobalKey<ft.TiptapEditorState>(), boundary = GlobalKey();
    await mount(
      tester,
      controller,
      key,
      boundary,
      const ft.TiptapEditorStyle(
        markerColor: red,
        ruleColor: Color(0xff0000ff),
        ruleHeights: {'wavy': 23},
      ),
    );
    final rect = key.currentState!.geometry!.rowRect(0);
    final pixels = await _pixels(boundary, tester);
    addTearDown(pixels.image.dispose);
    double middle(double x) {
      final ys = pixels.column(x);
      return (ys.first + ys.last + 1) / 8;
    }

    expect(middle(rect.left + 3), closeTo(rect.center.dy - 1.25, .2));
    expect(middle(rect.left + 9), closeTo(rect.center.dy + 1.25, .2));
    expect(middle(rect.left + 15), closeTo(middle(rect.left + 3), .01));
    expect(pixels.thickness(rect.left + 3), closeTo(1.3, .1));
    expect(pixels.bounds.top, closeTo(rect.center.dy - 1.25 - .65, .3));
    expect(pixels.bounds.bottom, closeTo(rect.center.dy + 1.25 + .65, .3));
  });
}
