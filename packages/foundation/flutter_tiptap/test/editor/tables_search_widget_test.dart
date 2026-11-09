import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/large_doc.dart';

class _Engine {
  _Engine(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.setClient') {
          client = (call.arguments as List).first as int;
        }
        if (call.method == 'TextInput.setEditingState') {
          final next = TextEditingValue.fromJSON(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          if (hold) {
            pending.add(next);
          } else {
            value = next;
          }
        }
        return null;
      },
    );
    addTearDown(() => tester.testTextInput.register());
  }
  final WidgetTester tester;
  int? client;
  bool hold = false;
  final pending = <TextEditingValue>[];
  TextEditingValue value = TextEditingValue.empty;
  Future<void> edit({
    String text = '',
    int? from,
    int? to,
    TextRange composing = TextRange.empty,
    bool selectionOnly = false,
  }) async {
    final old = value;
    from ??= old.selection.start;
    to ??= old.selection.end;
    final caret = selectionOnly
        ? old.selection.extentOffset
        : from + text.length;
    value = TextEditingValue(
      text: selectionOnly ? old.text : old.text.replaceRange(from, to, text),
      selection: TextSelection.collapsed(offset: caret),
      composing: composing,
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          client!,
          {
            'deltas': [
              {
                'oldText': old.text,
                'deltaStart': selectionOnly ? -1 : from,
                'deltaEnd': selectionOnly ? -1 : to,
                'deltaText': text,
                'selectionBase': caret,
                'selectionExtent': caret,
                'composingBase': composing.start,
                'composingExtent': composing.end,
              },
            ],
          },
        ]),
      ),
      (_) {},
    );
  }
}

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
      final engine = _Engine(tester),
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
  testWidgets(
    'table hit testing targets painted cells and selection paints their boxes',
    (tester) async {
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
      controller.setSelection(ft.CellSelection.row(controller.state.doc, cell));
      await tester.pump();
      expect(controller.state.selection, isA<ft.CellSelection>());
      expect(key.currentState!.debugCellSelectionRects, hasLength(3));
      final rects = key.currentState!.debugCellSelectionRects;
      expect(rects[0].top, rects[1].top);
      expect(rects[0].right, closeTo(rects[1].left, .01));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('2000-row table only lays out viewport rows and one edited row', (
    tester,
  ) async {
    final engine = _Engine(tester);
    final controller = ft.TiptapController(doc: generateLargeTableDocument());
    final key = await mount(tester, controller);
    expect(key.currentState!.geometry!.rowCount, 2001);
    expect(controller.diagnostics.visibleRows, lessThan(30));
    expect(controller.diagnostics.rowLayouts, lessThan(40));
    final scroll = key.currentState!.scrollController;
    scroll.jumpTo(scroll.position.maxScrollExtent * .5);
    await tester.pump();
    await tester.pump();
    expect(controller.diagnostics.visibleRows, lessThan(30));
    final geometry = key.currentState!.geometry!,
        position = geometry.positionForOffset(const Offset(80, 120));
    controller.setSelection(ft.TextSelection(position));
    await tester.pump();
    await tester.pump();
    key.currentState!.requestKeyboard();
    await tester.pump();
    final before = controller.diagnostics.paragraphLayouts;
    await engine.edit(text: '中');
    await tester.pump();
    expect(
      controller.diagnostics.paragraphLayouts - before,
      lessThanOrEqualTo(8),
    );
    expect(controller.diagnostics.lastLaidOutRows, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '3M search paints visible matches before chunked total finishes and reuses other blocks',
    (tester) async {
      final controller = ft.TiptapController(
        doc: generateLargeDocument(3000000),
      );
      final key = await mount(tester, controller);
      controller.startSearch('日');
      await tester.pump();
      expect(key.currentState!.debugSearchHighlightRects, isNotEmpty);
      for (
        var i = 0;
        i < 1000 && !controller.searchStatus.value.complete;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      expect(controller.searchStatus.value.complete, isTrue);
      expect(controller.searchStatus.value.total, greaterThan(1000));
      expect(controller.diagnostics.visibleRows, lessThan(50));
      final old = controller.searchScannedBlocks;
      controller.exec('insertText', {'text': '中'});
      for (
        var i = 0;
        i < 1000 && !controller.searchStatus.value.complete;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      expect(controller.searchScannedBlocks - old, lessThanOrEqualTo(1));
      controller.clearSearch();
      await tester.pump();
      expect(key.currentState!.debugSearchHighlightRects, isEmpty);
    },
  );
  testWidgets(
    'CellSelection highlight changes pixels only inside selected cells',
    (tester) async {
      final controller = ft.TiptapController(
            doc: generateLargeTableDocument(rows: 3, columns: 3),
          ),
          boundary = GlobalKey();
      final key = await mount(tester, controller, boundary: boundary);
      final map = ft.TableMap.get(controller.state.doc.child(0)),
          position = map.map[0] + 1,
          rect = key.currentState!.geometry!.cellRect(position)!;
      Future<List<int>> pixel() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await render.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return data!;
        });
        final index =
            ((rect.bottom - 5).toInt() * render.size.width.toInt() +
                (rect.right - 5).toInt()) *
            4;
        return List.generate(4, (i) => bytes!.getUint8(index + i));
      }

      final before = await pixel();
      controller.setSelection(ft.CellSelection(controller.state.doc, position));
      await tester.pump();
      final after = await pixel();
      expect(after, isNot(before));
      expect(after[2], greaterThan(after[0]));
    },
  );
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
      ft.Node cell(String value) => schema.node(
        'tableCell',
        content: [
          schema.node('paragraph', content: [schema.node('text', text: value)]),
        ],
      );
      final table = schema.node(
        'table',
        content: [
          schema.node(
            'tableRow',
            content: [
              schema.node(
                'tableCell',
                attrs: {'rowspan': 2},
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
  testWidgets(
    'mouse dragging between cells produces a rectangular CellSelection',
    (tester) async {
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
      expect(controller.state.selection, isA<ft.CellSelection>());
      expect(
        (controller.state.selection as ft.CellSelection).cells,
        hasLength(4),
      );
      expect(controller.toolbar.value.selectionKind, ft.SelectionKind.cell);
    },
  );
}
