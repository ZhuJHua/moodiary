import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final p = TestNodes(schema).p;
  const source = 'const double = (value) => 21;';
  const red = Color(0xffb02040), blue = Color(0xff244fa0);
  final colors = <TextSpan>[
    const TextSpan(
      text: 'const',
      style: TextStyle(color: red),
    ),
    const TextSpan(text: ' double = (value) => '),
    const TextSpan(
      text: '2',
      style: TextStyle(color: blue),
    ),
    const TextSpan(
      text: '1',
      style: TextStyle(color: blue),
    ),
    const TextSpan(text: ';'),
  ];
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      'highlighted code pixels match plain Text colour runs on $platform',
      (tester) async {
        final code = schema.node(
          'codeBlock',
          content: [schema.node('text', text: source)],
        );
        final style = const ft.TiptapEditorStyle().forBlock(code);
        expect(
          style.fontFamily,
          platform == TargetPlatform.android ? 'monospace' : 'Menlo',
        );
        final controller = ft.TiptapController(
          doc: schema.node('doc', content: [code]),
        );
        addTearDown(controller.dispose);
        final editorKey = GlobalKey(), textKey = GlobalKey();
        final widgetKey = GlobalKey<ft.TiptapEditorState>();
        TextSpan highlight(String? language, String text) => TextSpan(
          // Host theme typography must never split the code into different fonts.
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 36,
            letterSpacing: 6,
            wordSpacing: 9,
            fontWeight: FontWeight.w900,
          ),
          children: [
            for (final run in colors)
              TextSpan(
                text: run.text,
                style: run.style?.copyWith(
                  fontFamily: 'sans-serif',
                  fontSize: 28,
                  letterSpacing: 4,
                ),
              ),
          ],
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: Row(
              children: [
                RepaintBoundary(
                  key: editorKey,
                  child: SizedBox(
                    width: 400,
                    height: 180,
                    child: ft.TiptapEditor(
                      key: widgetKey,
                      controller: controller,
                      readOnly: true,
                      codeHighlighter: highlight,
                      style: const ft.TiptapEditorStyle(overflowFadeWidth: 0),
                    ),
                  ),
                ),
                RepaintBoundary(
                  key: textKey,
                  child: Container(
                    width: 400,
                    height: 180,
                    color: const Color(0xfff1f3f5),
                    padding: const EdgeInsets.only(left: 28, top: 44),
                    alignment: Alignment.topLeft,
                    child: Text.rich(
                      TextSpan(children: colors),
                      style: style.copyWith(inherit: false),
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        final height =
            (widgetKey.currentState!.geometry!.rowRect(1).height - 40).ceil();
        Future<List<int>> pixels(GlobalKey key) async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final result = <int>[];
          for (var y = 44; y < 44 + height; y++) {
            for (var x = 28; x < 372; x++) {
              final offset = (y * image.width + x) * 4;
              result.addAll(bytes!.buffer.asUint8List(offset, 4));
            }
          }
          image.dispose();
          return result;
        }

        final images = await tester.runAsync(
          () async => [await pixels(editorKey), await pixels(textKey)],
        );
        expect(images![0], images[1]);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'disc circle and square are bounded baseline-aligned shapes at three depths',
    (tester) async {
      final list = TestNodes(schema).list;
      final item = TestNodes(schema).item;
      final root = schema.node(
        'doc',
        content: [
          list([
            item([
              p('first'),
              list([
                item([
                  p('second'),
                  list([
                    item([p('third')]),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ],
      );
      final controller = ft.TiptapController(doc: root);
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>();
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: true,
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        final position = root.rowAt(i).position + 1;
        final marker = key.currentState!.debugListMarker(position)!;
        expect(marker.kind, ['disc', 'circle', 'square'][i]);
        expect(marker.bounds.width, closeTo(17 * .35, .001));
        expect(marker.bounds.height, closeTo(marker.bounds.width, .0001));
        expect(marker.bounds.bottom, lessThan(marker.textBaseline));
        expect(
          marker.bounds.center.dy,
          greaterThan(key.currentState!.geometry!.caretRect(position).top),
        );
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'bullet size and x-height centre stay fixed when first-line leading changes',
    (tester) async {
      for (final height in [1.4, 1.75, 2.2]) {
        final root = schema.node(
          'doc',
          content: [
            schema.node(
              'bulletList',
              content: [
                schema.node('listItem', content: [p('first line')]),
              ],
            ),
          ],
        );
        final controller = ft.TiptapController(doc: root),
            key = GlobalKey<ft.TiptapEditorState>();
        await tester.pumpWidget(
          CupertinoApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              readOnly: true,
              style: ft.TiptapEditorStyle(
                paragraph: TextStyle(fontSize: 17, height: height),
              ),
            ),
          ),
        );
        await tester.pump();
        final marker = key.currentState!.debugListMarker(
          root.rowAt(0).position + 1,
        )!;
        expect(marker.bounds.width, closeTo(17 * .35, .001));
        expect(
          marker.textBaseline - marker.bounds.center.dy,
          closeTo(17 * .26, .001),
        );
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  for (final size in [13.0, 17.0, 19.0, 21.0, 24.0, 25.0, 28.0, 32.0, 36.0]) {
    testWidgets(
      'ordered marker shares first text baseline at font size $size',
      (tester) async {
        final root = schema.node(
          'doc',
          content: [
            schema.node(
              'orderedList',
              attrs: {'start': 21},
              content: [
                schema.node(
                  'listItem',
                  content: [
                    p('paragraph'),
                    schema.node(
                      'heading',
                      attrs: {'level': 1},
                      content: [schema.node('text', text: 'heading')],
                    ),
                  ],
                ),
                schema.node('listItem', content: [p('second')]),
              ],
            ),
          ],
        );
        final controller = ft.TiptapController(doc: root);
        addTearDown(controller.dispose);
        final key = GlobalKey<ft.TiptapEditorState>();
        await tester.pumpWidget(
          CupertinoApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              readOnly: true,
              style: ft.TiptapEditorStyle(
                paragraph: TextStyle(fontSize: size, height: 1.7),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final index in [0, 2]) {
          final marker = key.currentState!.debugListMarker(
            root.rowAt(index).position + 1,
          )!;
          expect(marker.kind, 'number');
          expect(marker.baseline, closeTo(marker.textBaseline, .0001));
        }
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
}
