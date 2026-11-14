import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/ime.dart';
import '../support/large_doc.dart';
import '../support/nodes.dart';

void main() {
  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    GlobalKey? boundary,
    double height = 600,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: CupertinoApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: ft.TiptapEditor(
                key: key,
                controller: controller,
                autofocus: true,
                style: const ft.TiptapEditorStyle(cacheExtent: 0),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    addTearDown(controller.dispose);
    return key;
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    testWidgets('cell IME and channel Tab are ordered on $platform', (
      tester,
    ) async {
      final engine = FakeIme(tester),
          doc = generateLargeTableDocument(rows: 3, columns: 3),
          controller = ft.TiptapController(doc: doc);
      final key = await mount(tester, controller);
      expect(controller.inTable, isTrue);
      final first = controller.cellPosition!;
      await engine.edit(
        text: '中文',
        composing: const TextRange(start: 1, end: 3),
      );
      await engine.edit(selectionOnly: true);
      expect(controller.state.doc.nodeAt(first)!.textContent, startsWith('中文'));
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.performAction', [
            engine.client!,
            'TextInputAction.next',
          ]),
        ),
        (_) {},
      );
      await tester.pump();
      expect(controller.cellPosition, greaterThan(first));
      final caret = key.currentState!.geometry!.caretRect(
        controller.state.selection.head,
      );
      expect(caret.left, greaterThan(150));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }
  testWidgets('desktop Tab selects next cell text; Shift Tab reverses', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: generateLargeTableDocument(rows: 3, columns: 3),
    );
    await mount(tester, controller);
    final first = controller.cellPosition;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.cellPosition, isNot(first));
    expect(controller.state.selection.empty, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.cellPosition, first);
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));
  testWidgets('table hit testing targets painted cells', (tester) async {
    final controller = ft.TiptapController(
      doc: generateLargeTableDocument(rows: 3, columns: 3),
    );
    final key = await mount(tester, controller),
        geometry = key.currentState!.geometry!;
    final table = controller.state.doc.child(0),
        map = ft.TableMap.get(table),
        cell = map.map[1] + 1;
    final caret = geometry.caretRect(cell + 2),
        origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
    await tester.tapAt(origin + caret.center);
    await tester.pump();
    expect(controller.cellPosition, cell);
    expect(controller.state.selection, isA<ft.TextSelection>());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'merged cell continuation uses the same painted text and IME geometry',
    (tester) async {
      final schema = ft.Schema.standard();
      final paragraph = schema.node(
        'paragraph',
        content: [
          for (var i = 0; i < 5; i++) ...[
            schema.node('text', text: 'line$i'),
            if (i < 4) schema.node('hardBreak'),
          ],
        ],
      );
      final cell = TestNodes(schema).textCell;
      final table = schema.node(
        'table',
        content: [
          schema.node(
            'tableRow',
            content: [
              schema.node(
                'tableCell',
                attrs: {'rowspan': 2, 'colspan': 2},
                content: [paragraph],
              ),
              cell('a'),
            ],
          ),
          schema.node('tableRow', content: [cell('b')]),
        ],
      );
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            table,
            for (var i = 0; i < 10; i++)
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'after')],
              ),
          ],
        ),
      );
      final key = await mount(tester, controller, height: 90),
          position = 4 + 24;
      controller.setSelection(ft.TextSelection(position));
      await tester.pump();
      await tester.pump();
      // Let the caret reveal finish gliding.
      await tester.pump(const Duration(milliseconds: 250));
      final geometry = key.currentState!.geometry!,
          caret = geometry.caretRect(position),
          box = geometry.cellRect(2)!;
      expect(box.contains(caret.center), isTrue);
      expect(caret.top, greaterThanOrEqualTo(0));
      expect(caret.bottom, lessThanOrEqualTo(90));
      final hit = geometry.positionForOffset(caret.center);
      expect(ft.tableContext(controller.state.doc, hit)!.cellPosition, 2);
      expect(controller.state.doc.resolve(hit).parent, same(paragraph));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mouse dragging between cells clamps to the anchor cell', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: generateLargeTableDocument(rows: 3, columns: 3),
    );
    final key = await mount(tester, controller),
        geometry = key.currentState!.geometry!,
        map = ft.TableMap.get(controller.state.doc.child(0));
    final origin = tester.getTopLeft(find.byType(ft.TiptapEditor)),
        from = geometry.caretRect(map.map.first + 3).center,
        to = geometry.caretRect(map.map[4] + 3).center;
    final gesture = await tester.startGesture(
      origin + from,
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.moveTo(origin + to);
    await gesture.up();
    await tester.pump();
    final cell = map.map.first + 1;
    expect(
      controller.state.selection,
      ft.TextSelection(
        cell + 2,
        cell + controller.state.doc.nodeAt(cell)!.nodeSize - 2,
      ),
    );
    expect(controller.toolbar.value.selectionKind, ft.SelectionKind.text);
  });

  for (final startHandle in [false, true]) {
    testWidgets(
      'touch ${startHandle ? 'start' : 'end'} handle clamps inside its anchor cell',
      (tester) async {
        final controller = ft.TiptapController(
          doc: generateLargeTableDocument(rows: 3, columns: 3),
        );
        final key = await mount(tester, controller);
        final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
        final map = ft.TableMap.get(controller.state.doc.child(0));
        final cell = map.map[4] + 1;
        final start = cell + 2,
            end = cell + controller.state.doc.nodeAt(cell)!.nodeSize - 2;
        await tester.tapAt(
          origin + key.currentState!.geometry!.caretRect(start).center,
        );
        await tester.pump();
        controller.setSelection(ft.TextSelection(start + 1, start + 4));
        await tester.pump();
        final handle = find.byKey(
          ValueKey('tiptap-handle-${startHandle ? 'start' : 'end'}'),
        );
        expect(handle, findsOneWidget);
        final point = tester.getTopLeft(handle) + const Offset(22, 15);
        final handlePosition = startHandle ? start + 1 : start + 4;
        final target = key.currentState!.geometry!
            .caretRect(map.map[startHandle ? 0 : 8] + 3)
            .center;
        final delta =
            target -
            key.currentState!.geometry!.caretRect(handlePosition).centerLeft;
        final gesture = await tester.startGesture(point);
        await gesture.moveTo(point + delta);
        await tester.pump();
        expect(
          controller.state.selection,
          startHandle
              ? ft.TextSelection(start + 4, start)
              : ft.TextSelection(start + 1, end),
        );
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
  testWidgets(
    'Shift click and reverse mouse drag clamp to the anchor cell',
    (tester) async {
      final controller = ft.TiptapController(
        doc: generateLargeTableDocument(rows: 3, columns: 3),
      );
      final key = await mount(tester, controller);
      final geometry = key.currentState!.geometry!;
      final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      final map = ft.TableMap.get(controller.state.doc.child(0));
      final cell = map.map[4] + 1, anchor = cell + 5;
      final target = origin + geometry.caretRect(map.map.first + 3).center;
      controller.setSelection(ft.TextSelection(anchor));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.state.selection, ft.TextSelection(anchor, cell + 2));
      final gesture = await tester.startGesture(
        origin + geometry.caretRect(anchor).center,
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.moveTo(target);
      await gesture.up();
      await tester.pump();
      expect(controller.state.selection, ft.TextSelection(anchor, cell + 2));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
  testWidgets(
    'Shift arrows stop at each cell edge and shrink within the cell',
    (tester) async {
      final controller = ft.TiptapController(
        doc: generateLargeTableDocument(rows: 3, columns: 3),
      );
      await mount(tester, controller);
      final map = ft.TableMap.get(controller.state.doc.child(0));
      final cell = map.map[4] + 1, start = cell + 2;
      final end = cell + controller.state.doc.nodeAt(cell)!.nodeSize - 2;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (final (position, key) in [
        (start, LogicalKeyboardKey.arrowLeft),
        (start, LogicalKeyboardKey.arrowUp),
        (end, LogicalKeyboardKey.arrowRight),
        (end, LogicalKeyboardKey.arrowDown),
      ]) {
        controller.setSelection(ft.TextSelection(position));
        await tester.sendKeyEvent(key);
        expect(controller.state.selection, ft.TextSelection(position));
      }
      controller.setSelection(ft.TextSelection(start + 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(
        controller.state.selection,
        ft.TextSelection(start + 1, start + 2),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(controller.state.selection, ft.TextSelection(start + 1));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
}
