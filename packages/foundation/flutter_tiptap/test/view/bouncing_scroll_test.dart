import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final p = TestNodes(schema).p;
  ft.Node targetText() => schema.node(
    'paragraph',
    content: [
      schema.node('text', text: 'AB'),
      schema.node('text', text: 'C', marks: [schema.mark('bold')]),
      schema.node('text', text: 'DE'),
    ],
  );

  for (final end in [false, true]) {
    for (final node in [false, true]) {
      for (final fling in [false, true]) {
        for (final lateCorrection in [false, true]) {
          testWidgets(
            '${end ? 'end' : 'start'} overscroll: stop-only tap then select ${node ? 'node' : 'painted text'} after ${fling ? 'drag/fling' : 'spring bounce'}${lateCorrection ? ' with a late bounce correction' : ''}',
            (tester) async {
              final blocks = [
                schema.node('image', attrs: {'src': 'start'}),
                targetText(),
                for (var i = 0; i < 24; i++) p('line $i'),
                schema.node(
                  'horizontalRule',
                  attrs: {'variant': 'text', 'label': 'rule'},
                ),
                targetText(),
                schema.node('image', attrs: {'src': 'end'}),
                p('tail'),
              ];
              final controller = ft.TiptapController(
                state: ft.EditorState(
                  doc: schema.node('doc', content: blocks),
                  selection: const ft.TextSelection(2),
                ),
              );
              addTearDown(controller.dispose);
              final key = GlobalKey<ft.TiptapEditorState>(),
                  boundary = GlobalKey();
              await tester.pumpWidget(
                CupertinoApp(
                  home: ScrollConfiguration(
                    behavior: const CupertinoScrollBehavior().copyWith(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                    ),
                    child: RepaintBoundary(
                      key: boundary,
                      child: ft.TiptapEditor(
                        key: key,
                        controller: controller,
                        style: const ft.TiptapEditorStyle(
                          paragraph: TextStyle(
                            fontFamily: 'Ahem',
                            fontSize: 20,
                            height: 1,
                            color: Color(0xff000000),
                          ),
                          marks: {'bold': TextStyle(color: Color(0xff00ff00))},
                          cacheExtent: 2000,
                        ),
                        nodeHeightEstimator: (_, _) => 120,
                        nodeViews: {
                          'image': (_, view) => SizedBox(
                            key: ValueKey('image-${view.node.attrs['src']}'),
                            height: 120,
                            child: const ColoredBox(color: Color(0xff999999)),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump();
              final scroll = key.currentState!.scrollController;
              expect(scroll.position.physics, isA<BouncingScrollPhysics>());
              if (end) {
                scroll.jumpTo(scroll.position.maxScrollExtent);
                await tester.pump();
                await tester.pump();
              }
              final extent = end
                  ? scroll.position.maxScrollExtent
                  : scroll.position.minScrollExtent;
              if (fling) {
                final gesture = await tester.startGesture(
                  const Offset(500, 300),
                );
                await gesture.moveBy(
                  Offset(0, end ? -40 : 40),
                  timeStamp: const Duration(milliseconds: 16),
                );
                await tester.pump(const Duration(milliseconds: 16));
                await gesture.moveBy(
                  Offset(0, end ? -120 : 120),
                  timeStamp: const Duration(milliseconds: 96),
                );
                await tester.pump(const Duration(milliseconds: 80));
                await gesture.up();
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 32));
              } else {
                scroll.jumpTo(extent + (end ? 150 : -150));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 32));
              }
              expect(scroll.position.outOfRange, isTrue);
              final rawOffset = scroll.offset;
              final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
              late Offset point;
              late int expected;
              if (node) {
                final image = find.byKey(
                  ValueKey('image-${end ? 'end' : 'start'}'),
                );
                final rect = tester.getRect(image);
                point = rect.center;
                expected = controller.state.doc.content.positionAt(
                  end ? 28 : 0,
                );
                expect(
                  key.currentState!.geometry!.rowRect(expected).shift(origin),
                  rect,
                );
              } else {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final result = await tester.runAsync(() async {
                  final image = await render.toImage();
                  final data = (await image.toByteData(
                    format: ui.ImageByteFormat.rawRgba,
                  ))!;
                  final width = image.width, height = image.height;
                  image.dispose();
                  var left = width, top = height, right = 0, bottom = 0;
                  for (var y = 0; y < height; y++) {
                    for (var x = 0; x < width; x++) {
                      final i = (y * width + x) * 4;
                      if (data.getUint8(i) == 0 &&
                          data.getUint8(i + 1) == 255 &&
                          data.getUint8(i + 2) == 0 &&
                          data.getUint8(i + 3) == 255) {
                        if (x < left) left = x;
                        if (x > right) right = x;
                        if (y < top) top = y;
                        if (y > bottom) bottom = y;
                      }
                    }
                  }
                  return Rect.fromLTRB(
                    left.toDouble(),
                    top.toDouble(),
                    right + 1.0,
                    bottom + 1.0,
                  );
                });
                expect(result!.width, greaterThan(0));
                point =
                    origin +
                    Offset(result.left + result.width * .25, result.center.dy);
                expected =
                    controller.state.doc.content.positionAt(end ? 27 : 1) + 3;
              }
              expect(
                (origin & key.currentState!.geometry!.viewportSize).contains(
                  point,
                ),
                isTrue,
              );
              expect(key.currentState!.geometry!.scrollOffset, rawOffset);
              expect(
                key.currentState!.geometry!.positionForOffset(point - origin),
                expected,
              );
              if (!node && !fling && !lateCorrection) {
                // A reveal at the visible edge must not clamp the bounce.
                final geometry = key.currentState!.geometry!;
                final edge = geometry.positionForOffset(
                  Offset(20, end ? 1 : geometry.viewportSize.height - 1),
                );
                controller.setSelection(ft.TextSelection(edge));
                await tester.pump();
                expect(scroll.offset, rawOffset);
              }
              final previousSelection = controller.state.selection;
              final previousFocus = FocusManager.instance.primaryFocus;
              final clientsBefore = tester.testTextInput.log
                  .where((call) => call.method == 'TextInput.setClient')
                  .length;
              final touch = await tester.startGesture(point);
              await tester.pump(const Duration(milliseconds: 12));
              if (lateCorrection) {
                // A viewport/physics update can restart the spring after down.
                // Selection must keep the hit from the frame the user touched.
                (scroll.position as ScrollPositionWithSingleContext)
                    .goBallistic(0);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 160));
                expect(
                  (key.currentState!.geometry!.scrollOffset - rawOffset).abs(),
                  greaterThan(1),
                );
              }
              await touch.up();
              expect(controller.state.selection, previousSelection);
              expect(FocusManager.instance.primaryFocus, same(previousFocus));
              expect(
                tester.testTextInput.log
                    .where((call) => call.method == 'TextInput.setClient')
                    .length,
                clientsBefore,
              );
              await tester.pumpAndSettle();
              // Once idle, the same content accepts a normal tap again.
              final idlePoint = node
                  ? tester
                        .getRect(
                          find.byKey(
                            ValueKey('image-${end ? 'end' : 'start'}'),
                          ),
                        )
                        .center
                  : origin +
                        key.currentState!.geometry!.caretRect(expected).center +
                        const Offset(1, 0);
              await tester.tapAt(idlePoint);
              expect(controller.state.selection.from, expected);
              expect(
                controller.state.selection,
                node ? isA<ft.NodeSelection>() : isA<ft.TextSelection>(),
              );
              await tester.pump();
              if (!node) {
                final caret = key.currentState!.geometry!.caretRect(expected);
                final update =
                    tester.testTextInput.log
                            .lastWhere(
                              (call) => call.method == 'TextInput.setCaretRect',
                            )
                            .arguments
                        as Map;
                expect(
                  Rect.fromLTWH(
                    (update['x'] as num).toDouble(),
                    (update['y'] as num).toDouble(),
                    (update['width'] as num).toDouble(),
                    (update['height'] as num).toDouble(),
                  ),
                  caret,
                );
              }
              if (!node) {
                // Independent of tap policy: animate an existing text selection
                // through the bounce.
                scroll.jumpTo(
                  (end
                          ? scroll.position.maxScrollExtent
                          : scroll.position.minScrollExtent) +
                      (end ? 150 : -150),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 16));
                expect(scroll.position.outOfRange, isTrue);
                controller.setSelection(
                  ft.TextSelection(expected, expected + 1),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 16));
                final caret = key.currentState!.geometry!.caretRect(expected);
                final handle = find.byKey(
                  const ValueKey('tiptap-handle-start'),
                );
                if (caret.top >= 0 &&
                    caret.bottom <=
                        key.currentState!.geometry!.viewportSize.height) {
                  expect(
                    ((tester.getTopLeft(handle) + const Offset(22, 22)) -
                            (origin + caret.topCenter - const Offset(0, 6)))
                        .distance,
                    lessThan(0.000001),
                  );
                }
              }
              if (!node && !fling && !lateCorrection) {
                controller.exec('setHeading', {'level': 2});
                await tester.pump();
                await tester.pump();
                final caret = key.currentState!.geometry!.caretRect(expected);
                final handle = find.byKey(
                  const ValueKey('tiptap-handle-start'),
                );
                expect(
                  ((tester.getTopLeft(handle) + const Offset(22, 22)) -
                          (origin + caret.topCenter - const Offset(0, 6)))
                      .distance,
                  lessThan(0.000001),
                );
              }
              await tester.pumpAndSettle();
            },
            variant: const TargetPlatformVariant({TargetPlatform.iOS}),
          );
        }
      }
    }
  }
}
