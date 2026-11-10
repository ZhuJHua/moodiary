import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

final _schema = ft.Schema.standard();
const _platforms = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

ft.Node _paragraph(String text) =>
    _schema.node('paragraph', content: [_schema.node('text', text: text)]);

ft.Node _block(bool table) => table
    ? _schema.node(
        'table',
        content: [
          _schema.node(
            'tableRow',
            content: [
              for (var column = 0; column < 24; column++)
                _schema.node(
                  'tableCell',
                  content: [_paragraph('cell $column')],
                ),
            ],
          ),
        ],
      )
    : _schema.node(
        'codeBlock',
        content: [_schema.node('text', text: 'wide code ' * 100)],
      );

Future<ft.TiptapEditorState> _mount(
  WidgetTester tester,
  ft.TiptapController controller, {
  double width = 320,
  double? touchSlop,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: ScrollConfiguration(
        behavior: const ScrollBehavior(),
        child: MediaQuery(
          data: MediaQueryData(
            gestureSettings: DeviceGestureSettings(touchSlop: touchSlop),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 480,
              child: ft.TiptapEditor(
                controller: controller,
                readOnly: true,
                style: const ft.TiptapEditorStyle(
                  wrapCodeBlocks: false,
                  tableFixedLayout: true,
                  tableMinColumnWidth: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor));
}

Future<void> _fling(WidgetTester tester, Offset point) async {
  await tester.flingFrom(point, const Offset(-100, 0), 1500);
  await tester.pump();
}

void main() {
  for (final table in [false, true]) {
    final name = table ? 'table' : 'code';
    ft.TiptapController controller() => ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _block(table),
          for (var paragraph = 0; paragraph < 60; paragraph++)
            _paragraph('page $paragraph'),
        ],
      ),
    );

    testWidgets('$name flings after release and settles within bounds', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      await _fling(
        tester,
        geometry.horizontalScrollMetrics(0)!.viewport.center,
      );
      final released = geometry.horizontalScrollMetrics(0)!.offset;
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        geometry.horizontalScrollMetrics(0)!.offset,
        greaterThan(released),
      );
      await tester.pumpAndSettle();
      final settled = geometry.horizontalScrollMetrics(0)!;
      expect(settled.offset, inInclusiveRange(0, settled.maxScrollExtent));
    }, variant: _platforms);

    testWidgets('$name touch holds a fling until release or cancellation', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      final point = geometry.horizontalScrollMetrics(0)!.viewport.center;
      for (final cancel in [false, true]) {
        await _fling(tester, point);
        await tester.pump(const Duration(milliseconds: 40));
        final gesture = await tester.startGesture(point);
        final held = geometry.horizontalScrollMetrics(0)!.offset;
        await tester.pump(const Duration(milliseconds: 120));
        expect(geometry.horizontalScrollMetrics(0)!.offset, held);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(geometry.horizontalScrollMetrics(0)!.offset, held);
      }
    }, variant: _platforms);

    testWidgets('$name respects an 8px device touch slop for a 10px drag', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor, touchSlop: 8);
      final geometry = state.geometry!;
      final gesture = await tester.startGesture(
        geometry.horizontalScrollMetrics(0)!.viewport.center,
      );
      await gesture.moveBy(const Offset(-9, 0));
      await gesture.moveBy(const Offset(-1, 0));
      await tester.pump();
      expect(geometry.horizontalScrollMetrics(0)!.offset, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('$name gives mostly vertical drags to the page', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      await tester.dragFrom(
        geometry.horizontalScrollMetrics(0)!.viewport.center,
        const Offset(2, -100),
      );
      await tester.pumpAndSettle();
      expect(geometry.scrollOffset, greaterThan(30));
      expect(geometry.horizontalScrollMetrics(0)!.offset, 0);
    }, variant: _platforms);

    testWidgets('$name uses platform edge physics and springs back', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      final gesture = await tester.startGesture(
        geometry.horizontalScrollMetrics(0)!.viewport.center,
      );
      await gesture.moveBy(const Offset(30, 0));
      for (var move = 0; move < 4; move++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          geometry.horizontalScrollMetrics(0)!.offset,
          defaultTargetPlatform == TargetPlatform.iOS ? lessThan(0) : 0,
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(geometry.horizontalScrollMetrics(0)!.offset, 0);
    }, variant: _platforms);

    testWidgets(
      '$name survives edits, shrinking content and deletion during flings',
      (tester) async {
        final editor = controller();
        addTearDown(editor.dispose);
        final state = await _mount(tester, editor), geometry = state.geometry!;
        final point = geometry.horizontalScrollMetrics(0)!.viewport.center;
        await _fling(tester, point);
        final beforeEdit = geometry.horizontalScrollMetrics(0)!.offset;
        editor.setSelection(ft.TextSelection(table ? 4 : 1));
        editor.insertPlainText('edited');
        expect(geometry.horizontalScrollMetrics(0)!.offset, beforeEdit);
        await tester.pumpAndSettle();
        final edited = geometry.horizontalScrollMetrics(0)!;
        expect(edited.offset, inInclusiveRange(0, edited.maxScrollExtent));
        await _fling(tester, point);
        if (!table) {
          editor.apply(
            editor.state.tr.replace(2, editor.state.doc.child(0).nodeSize - 1),
          );
          await tester.pumpAndSettle();
          expect(geometry.horizontalScrollMetrics(0)!.offset, 0);
          editor.replaceDocument(
            _schema.node('doc', content: [_block(false), _paragraph('after')]),
          );
          await tester.pumpAndSettle();
          await _fling(tester, point);
        }
        editor.apply(
          editor.state.tr.replace(0, editor.state.doc.child(0).nodeSize),
        );
        await tester.pumpAndSettle();
        expect(geometry.horizontalScrollMetrics(0), isNull);
        expect(tester.takeException(), isNull);
      },
      variant: _platforms,
    );

    testWidgets('$name reapplies dimensions when its viewport changes', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      await _fling(
        tester,
        geometry.horizontalScrollMetrics(0)!.viewport.center,
      );
      final oldExtent = geometry.horizontalScrollMetrics(0)!.maxScrollExtent;
      final resized = await _mount(tester, editor, width: 500);
      expect(resized, same(state));
      final metrics = geometry.horizontalScrollMetrics(0)!;
      expect(metrics.maxScrollExtent, lessThan(oldExtent));
      expect(metrics.offset, inInclusiveRange(0, metrics.maxScrollExtent));
      expect(tester.takeException(), isNull);
    }, variant: _platforms);

    testWidgets('$name wheel and shift wheel stop its fling and scroll', (
      tester,
    ) async {
      final editor = controller();
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      final point = geometry.horizontalScrollMetrics(0)!.viewport.center;
      for (final shift in [false, true]) {
        await _fling(tester, point);
        await tester.pump(const Duration(milliseconds: 40));
        final before = geometry.horizontalScrollMetrics(0)!.offset;
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: point,
            scrollDelta: shift ? const Offset(0, 20) : const Offset(20, 0),
          ),
        );
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(
          geometry.horizontalScrollMetrics(0)!.offset,
          closeTo(before + 20, .01),
        );
        expect(geometry.scrollOffset, 0);
      }
    }, variant: _platforms);
  }

  testWidgets(
    'binding another block stops the previous fling and keeps its offset',
    (tester) async {
      final first = _block(false);
      final editor = ft.TiptapController(
        doc: _schema.node('doc', content: [first, _block(true)]),
      );
      addTearDown(editor.dispose);
      final state = await _mount(tester, editor), geometry = state.geometry!;
      await _fling(
        tester,
        geometry.horizontalScrollMetrics(0)!.viewport.center,
      );
      await tester.pump(const Duration(milliseconds: 40));
      final before = geometry.horizontalScrollMetrics(0)!.offset;
      final gesture = await tester.startGesture(
        geometry.horizontalScrollMetrics(first.nodeSize)!.viewport.center,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(geometry.horizontalScrollMetrics(0)!.offset, before);
      await gesture.up();
      await tester.pumpAndSettle();
    },
    variant: _platforms,
  );
}
