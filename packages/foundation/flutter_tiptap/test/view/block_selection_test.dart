import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  final schema = ft.Schema.standard();
  ft.Node p(String text) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    double estimate = 400,
    GlobalKey? boundary,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xffffffff),
            child: ft.TiptapEditor(
              key: key,
              controller: controller,
              style: const ft.TiptapEditorStyle(cacheExtent: 0),
              nodeHeightEstimator: (_, _) => estimate,
              nodeViews: {
                'image': (_, view) => SizedBox(
                  key: ValueKey('image-${view.node.attrs['src']}'),
                  height: 140,
                  child: const ColoredBox(color: Color(0xffeeeeee)),
                ),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(controller.dispose);
    return key;
  }

  testWidgets(
    'first tap after entering unmeasured atoms uses displayed geometry without scrolling',
    (tester) async {
      final code = schema.node(
        'codeBlock',
        content: [schema.node('text', text: 'x' * 20000)],
      );
      final blocks = [
        p('start'),
        for (var i = 0; i < 30; i++) p('before $i'),
        code,
        for (var i = 0; i < 40; i++)
          schema.node(
            'horizontalRule',
            attrs: {'variant': i.isEven ? 'double' : 'solid'},
          ),
        schema.node('image', attrs: {'src': 'target', 'widthPercent': 50}),
        for (var i = 0; i < 30; i++) p('after $i'),
      ];
      final controller = ft.TiptapController(
        doc: schema.node('doc', content: blocks),
      );
      final key = await mount(tester, controller);
      final geometry = key.currentState!.geometry!,
          scroll = key.currentState!.scrollController;
      final imagePosition = controller.state.doc.content.positionAt(72);
      final estimate = geometry.rowRect(imagePosition).top + scroll.offset;
      expect(find.byKey(const ValueKey('image-target')), findsNothing);
      scroll.jumpTo(estimate - 180);
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 6 &&
            find.byKey(const ValueKey('image-target')).evaluate().isEmpty;
        attempt++
      ) {
        scroll.jumpTo(
          (geometry.rowRect(imagePosition).top + scroll.offset - 180).clamp(
            0.0,
            scroll.position.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      final target = find.byKey(const ValueKey('image-target'));
      expect(target, findsOneWidget);
      final box = tester.getRect(target),
          origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      final offset = scroll.offset;
      // Public geometry reads must never remeasure an unvisited row and move the
      // scroll position or the node view that was just painted.
      geometry.rowRect(controller.state.doc.content.positionAt(31));
      expect(scroll.offset, offset);
      expect(geometry.positionForOffset(box.center - origin), imagePosition);
      await tester.tapAt(box.center);
      await tester.pump();
      await tester.pump();
      expect(controller.state.selection, isA<ft.NodeSelection>());
      expect(controller.state.selection.from, imagePosition);
      expect(scroll.offset, offset);
      expect(tester.getRect(target), box);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'hit testing between scroll notification and layout uses the laid-out node view',
    (tester) async {
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            for (var i = 0; i < 60; i++) p('line $i'),
            schema.node('image', attrs: {'src': 'target'}),
            for (var i = 0; i < 60; i++) p('tail $i'),
          ],
        ),
      );
      final key = await mount(tester, controller);
      final geometry = key.currentState!.geometry!,
          scroll = key.currentState!.scrollController;
      final position = controller.state.doc.content.positionAt(60);
      scroll.jumpTo(geometry.rowRect(position).top - 150);
      await tester.pump();
      final box = tester.getRect(find.byKey(const ValueKey('image-target')));
      final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      scroll.jumpTo(scroll.offset + 100);
      expect(geometry.positionForOffset(box.center - origin), position);
      await tester.pump();
    },
  );

  testWidgets(
    'NodeSelection has no text handles and text ranges retain both handles',
    (tester) async {
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node('image', attrs: {'src': 'target'}),
            p('text'),
          ],
        ),
      );
      final key = await mount(tester, controller);
      await tester.tap(find.byKey(const ValueKey('image-target')));
      await tester.pump();
      await tester.pump();
      for (final name in ['caret', 'start', 'end']) {
        expect(find.byKey(ValueKey('tiptap-handle-$name')), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('image-target')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      controller.setSelection(const ft.TextSelection(2, 5));
      key.currentState!.requestKeyboard();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('tiptap-handle-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('tiptap-handle-end')), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final width in [50, 75]) {
    testWidgets(
      'narrow $width% media selection is node-sized and paints an outline only',
      (tester) async {
        final controller = ft.TiptapController(
          doc: schema.node(
            'doc',
            content: [
              schema.node(
                'image',
                attrs: {'src': 'target', 'widthPercent': width},
              ),
              p('tail'),
            ],
          ),
        );
        final boundary = GlobalKey();
        final key = await mount(tester, controller, boundary: boundary);
        controller.setSelection(ft.NodeSelection(controller.state.doc, 0));
        await tester.pump();
        await tester.pump();
        final geometry = key.currentState!.geometry!,
            node = geometry.rowRect(0);
        expect(geometry.selectionRects(0, 1), [node]);
        expect(controller.selectedNode.value!.rect, node);
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
        final x = (node.right + 20).toInt(),
            y = node.center.dy.toInt(),
            index = (y * render.size.width.toInt() + x) * 4;
        expect(
          [
            bytes!.getUint8(index),
            bytes.getUint8(index + 1),
            bytes.getUint8(index + 2),
            bytes.getUint8(index + 3),
          ],
          [255, 255, 255, 255],
        );
      },
    );
  }
}
