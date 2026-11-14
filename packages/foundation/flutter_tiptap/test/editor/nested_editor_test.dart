import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/ime.dart';
import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final p = TestNodes(schema).p;
  final item = TestNodes(schema).textItem;
  final doc = TestNodes(schema).doc;
  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    bool readOnly = false,
    bool autofocus = true,
    ft.TiptapCodeHighlighter? highlighter,
    ft.TiptapEditorStyle style = const ft.TiptapEditorStyle(),
    GlobalKey? boundary,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: RepaintBoundary(
          key: boundary,
          child: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: readOnly,
            autofocus: autofocus,
            style: style,
            codeHighlighter: highlighter,
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    addTearDown(controller.dispose);
    return key;
  }

  testWidgets(
    'nested quote/list rows have indentation, ordered starts and matching geometry',
    (tester) async {
      final root = doc([
        schema.node(
          'blockquote',
          content: [
            schema.node(
              'orderedList',
              attrs: {'start': 7},
              content: [
                schema.node(
                  'listItem',
                  content: [
                    p('first'),
                    schema.node('bulletList', content: [item('inner')]),
                  ],
                ),
                item('second'),
              ],
            ),
          ],
        ),
        p('tail'),
      ]);
      final controller = ft.TiptapController(doc: root);
      final key = await mount(tester, controller, readOnly: true);
      final geometry = key.currentState!.geometry!;
      expect(geometry.rowCount, 4);
      final first = geometry.caretRect(root.rowAt(0).position + 1),
          inner = geometry.caretRect(root.rowAt(1).position + 1);
      const style = ft.TiptapEditorStyle();
      final marker = TextPainter(
        text: TextSpan(text: '8.', style: style.paragraph),
        textDirection: TextDirection.ltr,
      )..layout();
      final gutter = marker.maxIntrinsicWidth + 8;
      marker.dispose();
      expect(first.left, closeTo(16 + 21.25 + gutter, .01));
      expect(inner.left, closeTo(first.left + 25.5, .01));
      expect(geometry.caretRect(root.rowAt(2).position + 1).left, first.left);
      for (var row = 0; row < root.rowCount; row++) {
        final position = root.rowAt(row).position + 2,
            caret = geometry.caretRect(position);
        expect(geometry.positionForOffset(caret.centerLeft), position);
        expect(
          geometry.wordBoundary(position).start,
          root.rowAt(row).position + 1,
        );
      }
      expect(
        geometry
            .selectionRects(
              root.rowAt(0).position + 1,
              root.rowAt(2).position + 2,
            )
            .length,
        greaterThanOrEqualTo(3),
      );
      controller.setSelection(
        ft.TextSelection(
          root.rowAt(1).position + 1,
          root.rowAt(2).position + 2,
        ),
      );
      expect(controller.selectedText, 'inner\ns');
    },
  );

  testWidgets(
    'checkbox toggles the addressed task, preserves selection, supports undo and readOnly',
    (tester) async {
      final root = doc([
        schema.node(
          'taskList',
          content: [
            schema.node(
              'taskItem',
              attrs: {'checked': false},
              content: [p('task')],
            ),
          ],
        ),
        p('tail'),
      ]);
      final controller = ft.TiptapController(doc: root);
      final key = await mount(tester, controller);
      final previous = controller.state.selection;
      final checkbox = key.currentState!.geometry!.taskCheckboxRect(
        root.rowAt(0).position,
      )!;
      await tester.tapAt(checkbox.center);
      await tester.pump();
      expect(controller.state.doc.child(0).child(0).attrs['checked'], isTrue);
      expect(controller.state.selection, previous);
      controller.exec('undo');
      await tester.pump();
      expect(controller.state.doc.child(0).child(0).attrs['checked'], isFalse);
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
      await tester.tapAt(
        key.currentState!.geometry!
            .taskCheckboxRect(root.rowAt(0).position)!
            .center,
      );
      expect(controller.state.doc.child(0).child(0).attrs['checked'], isFalse);
    },
  );

  testWidgets(
    'code lines preserve whitespace and scroll horizontally with the caret',
    (tester) async {
      final text = "const longLine = ${List.filled(120, 'value').join(' + ')};";
      final code = schema.node(
        'codeBlock',
        attrs: {'language': 'javascript'},
        content: [schema.node('text', text: text)],
      );
      final controller = ft.TiptapController(doc: doc([code, p('tail')]));
      final key = await mount(tester, controller);
      final geometry = key.currentState!.geometry!;
      expect(geometry.rowRect(1).height, lessThan(80));
      controller.setSelection(ft.TextSelection(text.length + 1));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final caret = geometry.caretRect(text.length + 1),
          card = geometry.rowRect(1);
      expect(caret.right, lessThanOrEqualTo(card.right - 11));
      expect(caret.left, greaterThanOrEqualTo(card.left + 12));
      expect(geometry.positionForOffset(caret.centerLeft), text.length + 1);
      controller.setSelection(const ft.TextSelection(1));
      await tester.pump();
      await tester.pump();
      expect(geometry.caretRect(1).left, 28);
    },
  );

  testWidgets(
    'all six horizontal rules paint differently and nested atoms are selectable',
    (tester) async {
      final pixels = <int>{};
      for (final variant in [
        'solid',
        'dashed',
        'dotted',
        'double',
        'wavy',
        'text',
      ]) {
        final controller = ft.TiptapController(
          doc: doc([
            schema.node(
              'horizontalRule',
              attrs: {
                'variant': variant,
                'label': variant == 'text' ? 'label' : null,
              },
            ),
            p('tail'),
          ]),
        );
        final boundary = GlobalKey();
        await mount(tester, controller, autofocus: false, boundary: boundary);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final hash = await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return Object.hashAll(bytes!.buffer.asUint8List());
        });
        pixels.add(hash!);
      }
      expect(pixels.length, 6);
      final root = doc([
        schema.node(
          'blockquote',
          content: [p('quote'), schema.node('horizontalRule'), p('after')],
        ),
      ]);
      final controller = ft.TiptapController(doc: root);
      final key = await mount(tester, controller);
      final atom = root.rowAt(1);
      await tester.tapAt(
        key.currentState!.geometry!.rowRect(atom.position).center,
      );
      await tester.pump();
      expect(controller.state.selection, const ft.TextSelection(10));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.state.doc.child(0).childCount, 2);
    },
    variant: const TargetPlatformVariant({TargetPlatform.linux}),
  );

  for (final kind in ['list', 'quote', 'code']) {
    testWidgets(
      'IME typing, Return and deletion inside $kind preserve channel ordering',
      (tester) async {
        final engine = FakeIme(tester);
        final block = kind == 'list'
            ? schema.node('bulletList', content: [item('')])
            : kind == 'quote'
            ? schema.node('blockquote', content: [p('')])
            : schema.node('codeBlock');
        final controller = ft.TiptapController(doc: doc([block, p('tail')]));
        await mount(tester, controller);
        await engine.edit(
          text: '中文',
          composing: const TextRange(start: 1, end: 3),
        );
        expect(controller.composing.isValid, isTrue);
        // Marked Return is owned by the IME. A hardware event must not split first.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(controller.state.doc.rowAt(0).node.textContent, '中文');
        }
        await engine.edit(selectionOnly: true);
        await engine.edit(text: '\n');
        await tester.pump();
        if (kind == 'code') {
          expect(controller.state.doc.child(0).textContent, '中文\n');
        } else {
          expect(controller.state.doc.rowAt(0).node.textContent, '中文');
        }
        final before = controller.state.doc.content.size;
        if (defaultTargetPlatform == TargetPlatform.android) {
          // Faithful KEYCODE_DEL: adapter has no fallback deletion when unhandled.
          final handled = await tester.sendKeyEvent(
            LogicalKeyboardKey.backspace,
          );
          expect(handled, isTrue);
        } else {
          await engine.edit(
            from: 0,
            to: 1,
          ); // surrounding-text deletion of the sentinel
        }
        await tester.pump();
        if (kind == 'quote') {
          expect(controller.state.doc.rowAt(1).path.length, 1);
          expect(controller.state.doc.rowAt(0).node.textContent, '中文');
        } else {
          expect(controller.state.doc.content.size, lessThan(before));
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets(
    'desktop structural key bindings indent, outdent, toggle and exit code',
    (tester) async {
      final controller = ft.TiptapController(doc: doc([p('text'), p('tail')]));
      await mount(tester, controller);
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      Future<void> chord(
        LogicalKeyboardKey key, {
        bool shift = false,
        bool alt = false,
      }) async {
        await tester.sendKeyDownEvent(modifier);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(key);
        if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }

      await chord(LogicalKeyboardKey.digit8, shift: true);
      expect(controller.state.doc.child(0).type, 'bulletList');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.state.doc.child(0).child(0).childCount, 2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await chord(LogicalKeyboardKey.digit7, shift: true);
      expect(controller.state.toolbar.activeNodes, contains('orderedList'));
      await chord(LogicalKeyboardKey.digit9, shift: true);
      expect(controller.state.toolbar.activeNodes, contains('taskList'));
      controller.replaceDocument(doc([p('code'), p('tail')]));
      await tester.pump();
      await chord(LogicalKeyboardKey.keyC, alt: true);
      expect(controller.state.doc.child(0).type, 'codeBlock');
      controller.setSelection(
        ft.TextSelection(controller.state.doc.child(0).nodeSize - 1),
      );
      await tester.pump();
      await chord(LogicalKeyboardKey.enter);
      expect(
        controller.state.doc
            .resolve(controller.state.selection.head)
            .parent
            .type,
        'paragraph',
      );
      await chord(LogicalKeyboardKey.keyB, shift: true);
      expect(controller.state.toolbar.activeNodes, contains('blockquote'));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
}
