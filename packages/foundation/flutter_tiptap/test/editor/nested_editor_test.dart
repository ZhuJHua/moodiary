import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
  final schema = ft.Schema.standard();
  ft.Node p(String text) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  ft.Node item(String text) => schema.node('listItem', content: [p(text)]);
  ft.Node doc(List<ft.Node> nodes) => schema.node('doc', content: nodes);
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
      expect(first.left, closeTo(16 + 21.25 + 25.5, .01));
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
    'visible code highlighting is cached and edits only rehighlight that node',
    (tester) async {
      final first = schema.node(
        'codeBlock',
        attrs: {'language': 'javascript'},
        content: [schema.node('text', text: 'const n = 1;')],
      );
      final second = schema.node(
        'codeBlock',
        attrs: {'language': 'rust'},
        content: [schema.node('text', text: 'let x = 2;')],
      );
      final controller = ft.TiptapController(
        doc: doc([
          first,
          for (var i = 0; i < 200; i++) p('row $i'),
          second,
          p('tail'),
        ]),
      );
      final calls = <String>[];
      TextSpan highlight(String? language, String text) {
        calls.add('$language:$text');
        return TextSpan(
          children: [
            TextSpan(
              text: text,
              style: const TextStyle(color: Color(0xffe00000)),
            ),
          ],
        );
      }

      final key = await mount(tester, controller, highlighter: highlight);
      expect(calls, ['javascript:const n = 1;']);
      final caret = key.currentState!.geometry!.caretRect(1);
      expect(caret.left, 28);
      expect(caret.top, 44);
      controller.setSelection(const ft.TextSelection(5));
      await tester.pump();
      expect(calls.length, 1);
      controller.exec('insertText', {'text': 'x'});
      await tester.pump();
      expect(calls.length, 2);
      controller.setSelection(
        ft.TextSelection(controller.state.doc.rowAt(201).position + 1),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(calls.last, 'rust:let x = 2;');
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
        final engine = _Engine(tester);
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
    '10k-item single list virtualises rows and IME lays out only the edited row',
    (tester) async {
      final engine = _Engine(tester);
      final root = generateLargeListDocument();
      final position = root.rowAt(10000).position + 4;
      final controller = ft.TiptapController(
        state: ft.EditorState(doc: root, selection: ft.TextSelection(position)),
        commands: const ft.EditorCommands(),
      );
      final key = await mount(tester, controller);
      expect(key.currentState!.geometry!.rowCount, 20000);
      expect(controller.diagnostics.visibleRows, lessThan(100));
      expect(controller.diagnostics.rowLayouts, lessThan(120));
      for (var i = 0; i < 20; i++) {
        final count = controller.diagnostics.paragraphLayouts;
        await tester.pump();
        await tester.pump();
        if (controller.diagnostics.paragraphLayouts == count) break;
      }
      final scans = controller.diagnostics.fullDocumentScans;
      final before = controller.diagnostics.paragraphLayouts;
      final oldOffset = key.currentState!.geometry!.scrollOffset;
      final oldRect = key.currentState!.geometry!.caretRect(
        controller.state.selection.head,
      );
      await engine.edit(text: '中');
      await tester.pump();
      await tester.pump();
      expect(controller.diagnostics.fullDocumentScans, scans);
      expect(
        controller.diagnostics.paragraphLayouts - before,
        1,
        reason:
            '${controller.diagnostics.lastLaidOutRows} offset=${key.currentState!.geometry!.scrollOffset} rows=${controller.state.doc.rowCount} old=$oldOffset oldRect=$oldRect newRect=${key.currentState!.geometry!.caretRect(controller.state.selection.head)}',
      );
      expect(controller.diagnostics.lastLaidOutRows, {10000});
      expect(controller.state.doc.rowAt(10000).node.textContent, contains('中'));
      expect(
        identical(
          root.rowAt(10001).node,
          controller.state.doc.rowAt(10001).node,
        ),
        isTrue,
      );
      controller.exec('splitListItem');
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(key.currentState!.geometry!.rowCount, 20001);
      expect(controller.diagnostics.fullDocumentScans, scans);
      controller.exec('undo');
      await tester.pump();
      expect(key.currentState!.geometry!.rowCount, 20000);
    },
  );

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
