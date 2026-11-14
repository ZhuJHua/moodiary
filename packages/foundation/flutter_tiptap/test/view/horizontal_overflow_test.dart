import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final p = TestNodes(schema).p;
  ft.Node table(int columns) => schema.node(
    'table',
    content: [
      for (var r = 0; r < 2; r++)
        schema.node(
          'tableRow',
          content: [
            for (var c = 0; c < columns; c++)
              schema.node('tableCell', content: [p('cell $r $c')]),
          ],
        ),
    ],
  );

  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    bool wrap = false,
    GlobalKey? boundary,
    Widget? header,
    bool readOnly = true,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 480,
            child: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: const Color(0xffffffff),
                child: ft.TiptapEditor(
                  key: key,
                  controller: controller,
                  readOnly: readOnly,
                  codeBlockHeader: header == null ? null : (_, _) => header,
                  style: ft.TiptapEditorStyle(
                    wrapCodeBlocks: wrap,
                    tableMinColumnWidth: 100,
                    codeBackground: const Color(0xffffffff),
                    overflowBackground: const Color(0xffffffff),
                    overflowIndicatorColor: const Color(0xff000000),
                    paragraph: const TextStyle(
                      fontSize: 16,
                      color: Color(0xff000000),
                    ),
                    codeBlock: const TextStyle(
                      fontSize: 16,
                      color: Color(0xff000000),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets(
    'narrow table fills the viewport and does not join horizontal drags',
    (tester) async {
      final c = ft.TiptapController(
        doc: schema.node('doc', content: [table(2)]),
      );
      addTearDown(c.dispose);
      final key = await mount(tester, c);
      final g = key.currentState!.geometry!;
      final metrics = g.horizontalScrollMetrics(1)!;
      expect(metrics.maxScrollExtent, 0);
      final a = g.cellRect(2)!, b = g.cellRect(12)!;
      expect(a.width, closeTo(metrics.viewport.width / 2, .01));
      expect(b.width, a.width);
      await tester.dragFrom(metrics.viewport.center, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(g.horizontalScrollMetrics(1)!.offset, 0);
    },
  );

  testWidgets(
    'wide tables scroll horizontally, retain offsets through edits and lock the drag axis',
    (tester) async {
      final c = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [table(4), for (var i = 0; i < 60; i++) p('page $i')],
        ),
      );
      addTearDown(c.dispose);
      final key = await mount(tester, c);
      final g = key.currentState!.geometry!;
      final m = g.horizontalScrollMetrics(1)!;
      expect(m.maxScrollExtent, closeTo(112, .01));
      final point = m.viewport.center;
      await tester.dragFrom(point, const Offset(-70, 2));
      await tester.pump();
      final scrolled = g.horizontalScrollMetrics(1)!;
      expect(scrolled.offset, greaterThan(20));
      expect(scrolled.indicatorOpacity, 1);
      c.setSelection(const ft.TextSelection(18, 18));
      c.insertPlainText('edited');
      await tester.pump();
      expect(
        g.horizontalScrollMetrics(1)!.offset,
        closeTo(scrolled.offset, .01),
      );
      await tester.pumpAndSettle();
      expect(g.horizontalScrollMetrics(1)!.indicatorOpacity, 0);
      final beforeY = g.scrollOffset;
      final beforeX = g.horizontalScrollMetrics(1)!.offset;
      await tester.dragFrom(point, const Offset(2, -100));
      await tester.pumpAndSettle();
      expect(g.scrollOffset, greaterThan(beforeY + 30));
      expect(g.horizontalScrollMetrics(1)!.offset, beforeX);
    },
  );

  testWidgets('unwrapped code gives vertical drags to the page', (
    tester,
  ) async {
    final c = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'codeBlock',
            content: [schema.node('text', text: 'code line ' * 50)],
          ),
          for (var i = 0; i < 60; i++) p('page $i'),
        ],
      ),
    );
    addTearDown(c.dispose);
    final key = await mount(tester, c);
    final g = key.currentState!.geometry!;
    final point = g.horizontalScrollMetrics(0)!.viewport.center;
    await tester.dragFrom(point, const Offset(2, -100));
    await tester.pumpAndSettle();
    expect(g.scrollOffset, greaterThan(30));
    expect(g.horizontalScrollMetrics(0)!.offset, 0);
  });

  testWidgets(
    'separate tables retain their own offsets when either table is edited',
    (tester) async {
      final c = ft.TiptapController(
        doc: schema.node('doc', content: [table(4), table(4)]),
      );
      addTearDown(c.dispose);
      final key = await mount(tester, c);
      final g = key.currentState!.geometry!;
      final second = c.state.doc.child(0).nodeSize;
      await tester.dragFrom(
        g.horizontalScrollMetrics(1)!.viewport.center,
        const Offset(-65, 0),
      );
      await tester.pumpAndSettle();
      final firstOffset = g.horizontalScrollMetrics(1)!.offset;
      await tester.dragFrom(
        g.horizontalScrollMetrics(second + 1)!.viewport.center,
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      final secondOffset = g.horizontalScrollMetrics(second + 1)!.offset;
      expect(secondOffset, greaterThan(firstOffset));
      c.setSelection(ft.TextSelection(second + 18, second + 18));
      c.insertPlainText('edit');
      await tester.pumpAndSettle();
      expect(g.horizontalScrollMetrics(1)!.offset, firstOffset);
      expect(g.horizontalScrollMetrics(second + 1)!.offset, secondOffset);
    },
  );

  testWidgets(
    'wrap disables code overflow; unwrapped drag leaves header fixed and typing reveals the caret',
    (tester) async {
      final c = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node(
              'codeBlock',
              content: [schema.node('text', text: 'a long code line ' * 12)],
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      var key = await mount(tester, c, wrap: true);
      var g = key.currentState!.geometry!;
      expect(g.horizontalScrollMetrics(0)!.maxScrollExtent, 0);
      await tester.dragFrom(
        g.horizontalScrollMetrics(0)!.viewport.center,
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      expect(g.horizontalScrollMetrics(0)!.offset, 0);
      const header = SizedBox(
        key: ValueKey('header'),
        child: Text('language / copy'),
      );
      key = await mount(tester, c, header: header);
      g = key.currentState!.geometry!;
      final headerBefore = tester.getRect(find.byKey(const ValueKey('header')));
      await tester.dragFrom(
        g.horizontalScrollMetrics(0)!.viewport.center,
        const Offset(-100, 0),
      );
      await tester.pump();
      expect(g.horizontalScrollMetrics(0)!.offset, greaterThan(30));
      expect(
        tester.getRect(find.byKey(const ValueKey('header'))),
        headerBefore,
      );
      // A new edit at the far end must reveal a caret beyond the current viewport.
      await tester.pumpAndSettle();
      c.setSelection(
        ft.TextSelection(
          c.state.doc.content.size - 1,
          c.state.doc.content.size - 1,
        ),
      );
      c.insertPlainText('typing');
      await tester.pumpAndSettle();
      final caret = g.caretRect(c.state.selection.head);
      expect(
        caret.right,
        lessThanOrEqualTo(g.horizontalScrollMetrics(0)!.viewport.right + .1),
      );
    },
  );

  testWidgets(
    'overflow fades use only hidden sides and the indicator fades after scrolling',
    (tester) async {
      final c = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node(
              'codeBlock',
              content: [
                schema.node(
                  'text',
                  text: 'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM',
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      final boundary = GlobalKey();
      final key = await mount(tester, c, boundary: boundary);
      final g = key.currentState!.geometry!;
      Future<int> ink(bool left) async => (await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rect = g.horizontalScrollMetrics(0)!.viewport;
        final x0 = (left ? rect.left + 1 : rect.right - 10).toInt();
        var total = 0;
        for (var y = rect.top.toInt(); y < rect.top.toInt() + 16; y++) {
          for (var x = x0; x < x0 + 8; x++) {
            total += 255 - bytes.getUint8((y * image.width + x) * 4);
          }
        }
        image.dispose();
        return total;
      }))!;

      final initialLeft = await ink(true), initialRight = await ink(false);
      expect(initialLeft, greaterThan(initialRight));
      await tester.dragFrom(
        g.horizontalScrollMetrics(0)!.viewport.center,
        const Offset(-100, 0),
      );
      await tester.pump();
      expect(g.horizontalScrollMetrics(0)!.indicatorOpacity, 1);
      expect(await ink(true), lessThan(initialLeft));
      await tester.pump(const Duration(milliseconds: 750));
      expect(
        g.horizontalScrollMetrics(0)!.indicatorOpacity,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(g.horizontalScrollMetrics(0)!.indicatorOpacity, 0);
      await tester.dragFrom(
        g.horizontalScrollMetrics(0)!.viewport.center,
        const Offset(-2000, 0),
      );
      await tester.pumpAndSettle();
      final end = g.horizontalScrollMetrics(0)!;
      expect(end.offset, end.maxScrollExtent);
      expect(await ink(false), greaterThan(initialRight));
    },
  );
}
