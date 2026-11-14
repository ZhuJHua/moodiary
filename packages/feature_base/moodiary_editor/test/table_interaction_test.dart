import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:mui/mui.dart';

import 'support/nodes.dart';
import 'support/settle.dart';

final _schema = ft.Schema.standard();

final _paragraph = TestNodes(_schema).p;

ft.Node _table({bool nested = false}) => _schema.node(
  'table',
  content: [
    for (var row = 0; row < 3; row++)
      _schema.node(
        'tableRow',
        content: [
          for (var column = 0; column < 3; column++)
            _schema.node(
              row == 0 ? 'tableHeader' : 'tableCell',
              content: row == 1 && column == 0
                  ? [
                      if (nested)
                        _table()
                      else
                        _schema.node(
                          'codeBlock',
                          attrs: {'language': 'dart'},
                          content: [
                            _schema.node(
                              'text',
                              text: 'final value = someVeryLongFunctionName(argumentOne, argumentTwo);\noranges',
                            ),
                          ],
                        ),
                    ]
                  : row == 1 && column == 1
                  ? [
                      _schema.node(
                        'bulletList',
                        content: [
                          for (final text in ['apples', 'oranges'])
                            _schema.node(
                              'listItem',
                              content: [_paragraph(text)],
                            ),
                        ],
                      ),
                    ]
                  : [_paragraph()],
            ),
        ],
      ),
  ],
);

Iterable<(ft.Node, int)> _nodes(ft.Node node, [int start = -1]) sync* {
  yield (node, start);
  var position = start + 1;
  for (final child in node.content) {
    yield* _nodes(child, position);
    position += child.nodeSize;
  }
}

class _Harness {
  final editor = GlobalKey<ft.TiptapEditorState>();
  final boundary = GlobalKey();
  final focus = FocusNode();
  ft.TiptapGeometry get geometry => editor.currentState!.geometry!;

  List<Rect> fades() {
    final rects = <Rect>[];
    expect(
      geometry,
      paints..everything((method, arguments) {
        if (method == #drawRect && (arguments[1] as Paint).shader != null) {
          rects.add(arguments[0] as Rect);
        }
        return true;
      }),
    );
    return rects;
  }

  Future<void> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    bool readOnly = false,
    bool mouseDrag = false,
  }) async {
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: mouseDrag ? const _MouseScrollBehavior() : null,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 402,
              height: 600,
              child: ColoredBox(
                color: const Color(0xffffffff),
                child: ft.TiptapEditor(
                  key: editor,
                  controller: controller,
                  focusNode: focus,
                  readOnly: readOnly,
                  style: buildEditorStyle(brightness: Brightness.light),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleEditor(tester);
  }

  Future<List<int>> pixel(
    WidgetTester tester,
    Offset point,
    double dpr,
  ) async => (await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index =
        ((point.dy * dpr).floor() * image.width + (point.dx * dpr).floor()) * 4;
    final result = [
      for (var channel = 0; channel < 4; channel++)
        data.getUint8(index + channel),
    ];
    image.dispose();
    return result;
  }))!;
}

class _MouseScrollBehavior extends MaterialScrollBehavior {
  const _MouseScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) callback, {
  TargetPlatform platform = TargetPlatform.iOS,
}) => testWidgets(
  description,
  callback,
  variant: TargetPlatformVariant.only(platform),
);

void main() {
  for (final readOnly in [true, false]) {
    for (final dpr in [2.0, 3.0]) {
      _testWidgets(
        'table edges at rest and maximum, readOnly=$readOnly dpr=$dpr',
        (tester) async {
          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize = Size(804 * dpr, 800 * dpr);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final controller = ft.TiptapController(
            doc: _schema.node('doc', content: [_table()]),
          );
          addTearDown(controller.dispose);
          final harness = _Harness();
          await harness.mount(tester, controller, readOnly: readOnly);
          final geometry = harness.geometry;
          final metrics = geometry.horizontalScrollMetrics(1)!;
          expect(metrics.offset, 0);
          expect(metrics.maxScrollExtent, greaterThan(0));
          final code = _nodes(controller.state.doc)
              .firstWhere((entry) => entry.$1.type == 'codeBlock')
              .$2;
          expect(geometry.horizontalScrollMetrics(code)!.offset, 0);
          final initialFades = harness.fades();
          expect(initialFades, hasLength(4));
          expect(
            initialFades,
            everyElement(
              predicate<Rect>((rect) => rect.left > metrics.viewport.left + 1),
            ),
          );
          final cell = geometry.cellRect(code)!;
          final left = Offset(metrics.viewport.left + .75, cell.bottom - 3);
          final border = await harness.pixel(tester, left, dpr);
          expect(
            border.take(3),
            everyElement(lessThan(220)),
            reason: 'full one-point left border',
          );
          await tester.dragFrom(
            metrics.viewport.topCenter + const Offset(0, 10),
            const Offset(-2000, 0),
          );
          await settleEditor(tester);
          final end = geometry.horizontalScrollMetrics(1)!;
          expect(end.offset, end.maxScrollExtent);
          final right = await harness.pixel(
            tester,
            Offset(end.viewport.right - .75, cell.bottom - 3),
            dpr,
          );
          expect(
            right.take(3),
            everyElement(lessThan(220)),
            reason: 'full one-point right border',
          );
          await tester.dragFrom(
            end.viewport.topCenter + const Offset(0, 10),
            const Offset(2000, 0),
          );
          await settleEditor(tester);
          expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
          expect(harness.fades(), initialFades);
          expect(await harness.pixel(tester, left, dpr), border);
        },
      );
    }
  }

  _testWidgets(
    'table insertion and column-two tap use final caret immediately',
    (tester) async {
      final controller = ft.TiptapController();
      addTearDown(controller.dispose);
      final harness = _Harness();
      await harness.mount(tester, controller);
      harness.focus.requestFocus();
      await settleEditor(tester);
      controller.exec('insertTable');
      await tester.pump();
      final inserted = harness.editor.currentState!.debugCaret.rect;
      final insertedPixel = await harness.pixel(tester, inserted!.center, 1);
      await settleEditor(tester);
      expect(inserted, harness.editor.currentState!.debugCaret.rect);
      expect(insertedPixel, await harness.pixel(tester, inserted.center, 1));
      final headers = _nodes(controller.state.doc)
          .where((entry) => entry.$1.type == 'tableHeader')
          .toList();
      final second = harness.geometry.cellRect(headers[1].$2)!;
      await tester.tapAt(second.topLeft + const Offset(20, 15));
      await tester.pump();
      final tapped = harness.editor.currentState!.debugCaret.rect;
      final tappedPixel = await harness.pixel(tester, tapped!.center, 1);
      await settleEditor(tester);
      expect(tapped, harness.editor.currentState!.debugCaret.rect);
      expect(tappedPixel, await harness.pixel(tester, tapped.center, 1));
      expect(tapped.left, greaterThan(second.left));
    },
  );

  _testWidgets(
    'nested table and cell code scroll independently at the left edge',
    (tester) async {
      final controller = ft.TiptapController(
        doc: _schema.node('doc', content: [_table(nested: true)]),
      );
      addTearDown(controller.dispose);
      final harness = _Harness();
      await harness.mount(tester, controller, readOnly: true);
      final entries = _nodes(controller.state.doc).toList();
      final nested = entries.where((entry) => entry.$1.type == 'table').last.$2;
      final code = entries
          .firstWhere((entry) => entry.$1.type == 'codeBlock')
          .$2;
      final geometry = harness.geometry;
      final tableMetrics = geometry.horizontalScrollMetrics(nested)!;
      final codeMetrics = geometry.horizontalScrollMetrics(code)!;
      expect(tableMetrics.offset, 0);
      expect(codeMetrics.offset, 0);
      final initial = harness.fades();
      expect(initial, isNotEmpty);
      expect(
        initial.where(
          (rect) => (rect.left - tableMetrics.viewport.left).abs() < .01,
        ),
        isEmpty,
      );
      expect(
        initial.where(
          (rect) => (rect.left - codeMetrics.viewport.left).abs() < .01,
        ),
        isEmpty,
      );
      await tester.dragFrom(
        tableMetrics.viewport.topCenter + const Offset(0, 5),
        const Offset(-40, 0),
      );
      await settleEditor(tester);
      expect(geometry.horizontalScrollMetrics(nested)!.offset, greaterThan(0));
      expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
      expect(geometry.horizontalScrollMetrics(code)!.offset, 0);
      await tester.dragFrom(
        tableMetrics.viewport.topCenter + const Offset(0, 5),
        const Offset(2000, 0),
      );
      await settleEditor(tester);
      expect(geometry.horizontalScrollMetrics(nested)!.offset, 0);
      expect(harness.fades(), initial);
      final codePoint = Offset(
        codeMetrics.viewport.left + 30,
        codeMetrics.viewport.top + 8,
      );
      await tester.dragFrom(codePoint, const Offset(-30, 0));
      await settleEditor(tester);
      expect(geometry.horizontalScrollMetrics(code)!.offset, greaterThan(0));
      expect(geometry.horizontalScrollMetrics(nested)!.offset, 0);
      expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
    },
  );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final code in [false, true]) {
      _testWidgets(
        '$kind horizontal ${code ? 'code' : 'table'} drag preserves focus and selection',
        (tester) async {
          final table = _table();
          final codeNode = _nodes(table)
              .firstWhere((entry) => entry.$1.type == 'codeBlock')
              .$1;
          final controller = ft.TiptapController(
            doc: _schema.node('doc', content: [code ? codeNode : table]),
          );
          addTearDown(controller.dispose);
          final harness = _Harness();
          await harness.mount(
            tester,
            controller,
            mouseDrag: kind == PointerDeviceKind.mouse,
          );
          final selection = controller.state.selection;
          final metrics = harness.geometry.horizontalScrollMetrics(
            code ? 0 : 1,
          )!;
          await tester.dragFrom(
            metrics.viewport.topCenter + const Offset(0, 10),
            const Offset(-80, 0),
            kind: kind,
          );
          await settleEditor(tester);
          expect(controller.state.selection, selection);
          expect(harness.focus.hasFocus, isFalse);
          expect(
            harness.geometry.horizontalScrollMetrics(code ? 0 : 1)!.offset,
            greaterThan(0),
          );
        },
        platform: kind == PointerDeviceKind.mouse
            ? TargetPlatform.macOS
            : TargetPlatform.iOS,
      );
    }
  }

  _testWidgets('touch scroll after editing a cell does not restore focus', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node('doc', content: [_table()]),
    );
    addTearDown(controller.dispose);
    final harness = _Harness();
    await harness.mount(tester, controller);
    harness.focus.requestFocus();
    final code = _nodes(controller.state.doc)
        .firstWhere((entry) => entry.$1.type == 'codeBlock');
    controller.setSelection(ft.TextSelection(code.$2 + code.$1.nodeSize - 1));
    controller.insertPlainText('edited');
    await settleEditor(tester);
    harness.focus.unfocus();
    await settleEditor(tester);
    final selection = controller.state.selection;
    final metrics = harness.geometry.horizontalScrollMetrics(1)!;
    await tester.dragFrom(
      metrics.viewport.topCenter + const Offset(0, 10),
      const Offset(-80, 0),
    );
    await settleEditor(tester);
    expect(harness.focus.hasFocus, isFalse);
    expect(controller.state.selection, selection);
    expect(harness.geometry.horizontalScrollMetrics(1)!.offset, greaterThan(0));
  });

  for (final mouseDrag in [false, true]) {
    _testWidgets(
      'mouse clicks and vertical selection survive mouseDrag=$mouseDrag',
      (tester) async {
        final controller = ft.TiptapController(
          doc: _schema.node('doc', content: [_table()]),
        );
        addTearDown(controller.dispose);
        final harness = _Harness();
        await harness.mount(tester, controller, mouseDrag: mouseDrag);
        final code = _nodes(controller.state.doc)
            .firstWhere((entry) => entry.$1.type == 'codeBlock');
        final point = harness.geometry.caretRect(code.$2 + 3).center;
        await tester.tapAt(point, kind: PointerDeviceKind.mouse);
        await settleEditor(tester);
        expect(harness.focus.hasFocus, isTrue);
        expect(
          controller.state.selection.head,
          harness.geometry.positionForOffset(point),
        );
        await tester.pump(const Duration(milliseconds: 401));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.down(point, timeStamp: const Duration(seconds: 1));
        final target = harness.geometry
            .caretRect(code.$2 + code.$1.textContent.indexOf('\n') + 3)
            .center;
        expect(
          harness.geometry.positionForOffset(target),
          isNot(controller.state.selection.head),
        );
        await gesture.moveTo(
          target,
          timeStamp: const Duration(milliseconds: 1010),
        );
        expect(
          controller.state.selection.empty,
          isFalse,
          reason: 'during mouse move',
        );
        await gesture.up(timeStamp: const Duration(milliseconds: 1020));
        expect(
          controller.state.selection.empty,
          isFalse,
          reason: 'after mouse up',
        );
        await settleEditor(tester);
        expect(
          controller.state.selection.empty,
          isFalse,
          reason:
              '${controller.state.selection.anchor}:${controller.state.selection.head}',
        );
        expect(harness.geometry.horizontalScrollMetrics(1)!.offset, 0);
      },
      platform: TargetPlatform.macOS,
    );
  }
}
