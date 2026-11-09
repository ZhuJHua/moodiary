import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  testWidgets('fixed table columns ignore cell text length when sizing media', (
    tester,
  ) async {
    final schema = ft.Schema.standard();
    final table = schema.node(
      'table',
      content: [
        schema.node(
          'tableRow',
          content: [
            for (final text in ['short', 'a much longer cell label'])
              schema.node(
                'tableCell',
                content: [
                  schema.node(
                    'paragraph',
                    content: [schema.node('text', text: text)],
                  ),
                  schema.node(
                    'image',
                    attrs: {'src': text, 'widthPercent': 50},
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    final controller = ft.TiptapController(
      doc: schema.node('doc', content: [table]),
    );
    addTearDown(controller.dispose);
    final widths = <String, double>{};
    Future<void> render(bool fixed) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            controller: controller,
            style: ft.TiptapEditorStyle(tableFixedLayout: fixed),
            nodeViews: {
              'image': (_, view) {
                widths[view.node.attrs['src']! as String] = view.width;
                return SizedBox(width: view.width, height: 30);
              },
            },
          ),
        ),
      );
      await tester.pump();
    }

    await render(false);
    expect(widths.values.first, isNot(closeTo(widths.values.last, .01)));
    await render(true);
    expect(widths.values.first, closeTo(widths.values.last, .01));
    expect(widths.values.first, closeTo(((800 - 32) / 2 - 20) / 2, .01));
  });

  testWidgets('read-only media hides edit-only node-selection chrome', (
    tester,
  ) async {
    final schema = ft.Schema.standard();
    final doc = schema.node(
      'doc',
      content: [
        schema.node('image', attrs: {'src': 'image.png'}),
        schema.node('paragraph'),
      ],
    );
    final controller = ft.TiptapController(doc: doc);
    controller.setSelection(ft.NodeSelection(doc, 0));
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    var selected = true;
    await tester.pumpWidget(
      CupertinoApp(
        home: RepaintBoundary(
          key: boundary,
          child: ft.TiptapEditor(
            controller: controller,
            readOnly: true,
            style: const ft.TiptapEditorStyle(caretColor: Color(0xffff0000)),
            nodeViews: {
              'image': (_, view) {
                selected = view.selected;
                return const ColoredBox(
                  color: Color(0xffffffff),
                  child: SizedBox(height: 80),
                );
              },
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    final redPixels = await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var count = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] == 255 && bytes[i + 1] == 0 && bytes[i + 2] == 0) {
          count++;
        }
      }
      image.dispose();
      return count;
    });
    expect(
      redPixels,
      0,
      reason: 'A saved document must not show an editing selection outline.',
    );
  });

  testWidgets(
    'table media mounts at document positions, measures, resizes, moves and deletes',
    (tester) async {
      final schema = ft.Schema.standard();
      final media = ['image', 'video', 'audio', 'attachment'];
      final doc = schema.node(
        'doc',
        content: [
          schema.node(
            'table',
            content: [
              schema.node(
                'tableRow',
                content: [
                  schema.node(
                    'tableCell',
                    content: [
                      schema.node('paragraph'),
                      for (final type in media)
                        schema.node(type, attrs: {'src': '$type.png'}),
                      schema.node('paragraph'),
                    ],
                  ),
                ],
              ),
            ],
          ),
          schema.node('paragraph'),
        ],
      );
      final controller = ft.TiptapController(doc: doc);
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>();
      final views = <String, ft.TiptapNodeView>{};
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            nodeViews: {
              for (final type in media)
                type: (context, view) {
                  views[type] = view;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.setSelection(
                      ft.NodeSelection(controller.state.doc, view.position),
                    ),
                    child: SizedBox(
                      key: ValueKey(type),
                      width: view.width,
                      height: view.width / 8,
                    ),
                  );
                },
            },
            nodeHeightEstimator: (_, width) => width / 10,
          ),
        ),
      );
      await tester.pump();
      final geometry = key.currentState!.geometry!;
      for (final type in media) {
        final view = views[type]!;
        expect(controller.state.doc.nodeAt(view.position)!.type, type);
        final rect = tester.getRect(find.byKey(ValueKey(type)));
        final modelRect = geometry.rowRect(view.position);
        expect(modelRect.top, closeTo(rect.top, .01));
        expect(modelRect.height, closeTo(rect.height, .01));
      }
      final before = views['image']!.width;
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('image'))));
      expect(controller.state.selection, isA<ft.NodeSelection>());
      controller.exec('setMediaWidth', {'percent': 50});
      await tester.pump();
      await tester.pump();
      expect(views['image']!.width, closeTo(before / 2, .01));
      expect(
        geometry.rowRect(views['video']!.position).top,
        greaterThanOrEqualTo(geometry.rowRect(views['image']!.position).bottom),
      );
      controller.exec('moveBlockDown');
      await tester.pump();
      expect(views['image']!.position, greaterThan(views['video']!.position));
      expect(
        controller.state.doc.nodeAt(views['image']!.position)!.type,
        'image',
      );
      controller.exec('deleteBlock');
      await tester.pump();
      expect(find.byKey(const ValueKey('image')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'host clipboard handler consumes image paste before plain text and blocks read-only paste',
    (tester) async {
      final controller = ft.TiptapController();
      addTearDown(controller.dispose);
      var reads = 0;
      Future<bool> paste() async {
        reads++;
        return true;
      }

      Future<void> mount(bool readOnly) => tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            controller: controller,
            autofocus: true,
            readOnly: readOnly,
            onPasteClipboard: paste,
          ),
        ),
      );
      await mount(false);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(reads, 1);
      await mount(true);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(reads, 1);
    },
  );
}
