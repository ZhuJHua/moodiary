import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/large_doc.dart';

void main() {
  final schema = ft.Schema.standard();
  ft.Node paragraph(String text) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  ft.TiptapController controller(List<ft.Node> blocks, {int position = 1}) =>
      ft.TiptapController(
        state: ft.EditorState(
          doc: schema.node('doc', content: blocks),
          selection: ft.TextSelection(position),
        ),
      );
  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    bool readOnly = false,
    bool autofocus = true,
    ft.TiptapEditorStyle style = const ft.TiptapEditorStyle(),
    ft.TiptapContextMenuBuilder? menu,
    bool systemMenu = false,
    ft.TiptapPasteText? onPasteText,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(supportsShowingSystemContextMenu: systemMenu),
          child: child!,
        ),
        home: ft.TiptapEditor(
          key: key,
          controller: controller,
          readOnly: readOnly,
          autofocus: autofocus,
          style: style,
          onPasteText: onPasteText,
          placeholder: 'Write…',
          contextMenuBuilder: menu,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(controller.dispose);
    return key;
  }

  Future<void> delta(
    WidgetTester tester,
    GlobalKey<ft.TiptapEditorState> key, {
    String text = '',
    int? from,
    int? to,
    TextRange composing = TextRange.empty,
    int? caret,
  }) async {
    final old = key.currentState!.debugInputValue;
    from ??= old.selection.start;
    to ??= old.selection.end;
    final client =
        (tester.testTextInput.log
                        .lastWhere(
                          (call) => call.method == 'TextInput.setClient',
                        )
                        .arguments
                    as List)
                .first
            as int;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          client,
          {
            'deltas': [
              {
                'oldText': old.text,
                'deltaStart': from,
                'deltaEnd': to,
                'deltaText': text,
                'selectionBase': caret ?? from + text.length,
                'selectionExtent': caret ?? from + text.length,
                'composingBase': composing.start,
                'composingExtent': composing.end,
              },
            ],
          },
        ]),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('first paint lays out the viewport before its offscreen cache', (
    tester,
  ) async {
    final c = controller(
      List.generate(200, (i) => paragraph('Row $i ${'text ' * 20}')),
    );
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: ft.TiptapEditor(
          key: key,
          controller: c,
          readOnly: true,
          style: const ft.TiptapEditorStyle(cacheExtent: 500),
        ),
      ),
    );
    final first = c.diagnostics.visibleBlocks;
    final rect = key.currentState!.geometry!.rowRect(0);
    expect(first, greaterThan(0));
    await tester.pump();
    expect(c.diagnostics.visibleBlocks, greaterThan(first));
    expect(key.currentState!.geometry!.rowRect(0), rect);
    c.replaceDocument(
      schema.node(
        'doc',
        content: List.generate(200, (i) => paragraph('New $i ${'text ' * 20}')),
      ),
    );
    await tester.pump();
    final replaced = c.diagnostics.visibleBlocks;
    await tester.pump();
    expect(c.diagnostics.visibleBlocks, greaterThan(replaced));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'delta client edits, geometry, marks, hard break and placeholder',
    (tester) async {
      final c = controller([paragraph('')]);
      final key = await mount(tester, c);
      expect(tester.testTextInput.setClientArgs!['enableDeltaModel'], isTrue);
      expect(key.currentState!.debugInputValue.text, '\u200b');
      await delta(tester, key, text: '你好😀');
      expect(c.state.doc.blocks.first.textContent, '你好😀');
      expect(c.state.selection.head, 5);
      final geometry = key.currentState!.geometry!;
      final rect = geometry.caretRect(3);
      expect(geometry.positionForOffset(rect.center), 3);
      expect(geometry.selectionRects(1, 3), isNotEmpty);
      c.exec('toggleMark', {'type': 'bold'});
      await delta(tester, key, text: 'B');
      expect(c.state.doc.blocks.first.content.last.marks.first.type, 'bold');
      c.exec('hardBreak');
      await tester.pump();
      expect(
        c.state.doc.blocks.first.content.any((n) => n.type == 'hardBreak'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live composition replaces text and commits input rules as one history event',
    (tester) async {
      final c = controller([paragraph('')]);
      final key = await mount(tester, c);
      await delta(
        tester,
        key,
        text: 'n',
        composing: const TextRange(start: 1, end: 2),
      );
      expect(c.state.doc.blocks.first.textContent, 'n');
      expect(c.composing, const TextRange(start: 1, end: 2));
      await delta(
        tester,
        key,
        from: 1,
        to: 2,
        text: '你',
        composing: const TextRange(start: 1, end: 2),
      );
      expect(c.state.doc.blocks.first.textContent, '你');
      key.currentState!.debugApplyDeltas([
        TextEditingDeltaNonTextUpdate(
          oldText: key.currentState!.debugInputValue.text,
          selection: const TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);
      await tester.pump();
      expect(c.composing, TextRange.empty);
      c.exec('undo');
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, '');
      c.exec('redo');
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, '你');
    },
  );

  testWidgets('IME select-all then clear empties the whole document', (
    tester,
  ) async {
    final c = controller([paragraph('ab'), paragraph('cd')], position: 2);
    final key = await mount(tester, c);
    final text = key.currentState!.debugInputValue.text;
    key.currentState!.debugApplyDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pump();
    expect(c.state.selection, isA<ft.AllSelection>());
    key.currentState!.debugApplyDeltas([
      TextEditingDeltaDeletion(
        oldText: text,
        deletedRange: TextRange(start: 0, end: text.length),
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pump();
    expect(c.state.doc.childCount, 1);
    expect(c.state.doc.blocks.first.textContent, '');
    expect(c.state.selection.head, 1);
    expect(key.currentState!.debugInputValue.text, '\u200b');
  });

  Future<void> imeClear(WidgetTester tester, ft.TiptapEditorState state) async {
    final text = state.debugInputValue.text;
    final selection = state.debugInputValue.selection;
    final caret = selection.start;
    TextEditingDelta select(int base, int extent) =>
        TextEditingDeltaNonTextUpdate(
          oldText: text,
          selection: TextSelection(baseOffset: base, extentOffset: extent),
          composing: TextRange.empty,
        );
    state.debugApplyDeltas([
      select(0, selection.end),
      select(0, caret),
      select(caret, caret),
      select(caret, caret),
      TextEditingDeltaDeletion(
        oldText: text,
        deletedRange: TextRange(start: 0, end: caret),
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pump();
  }

  for (final (name, code, position, expected) in [
    ('the caret', 'cdef', 7, 'ef'),
    ('its end', 'cdef', 9, ''),
    ('a later line', 'cd\nef', 10, ''),
  ]) {
    testWidgets('an IME clear in a code block stops at $name', (tester) async {
      final c = controller([
        paragraph('ab'),
        schema.node('codeBlock', content: [schema.node('text', text: code)]),
        paragraph('gh'),
      ], position: position);
      final key = await mount(tester, c);
      await imeClear(tester, key.currentState!);
      expect(c.state.doc.childCount, 3);
      expect(c.state.doc.blocks.first.textContent, 'ab');
      expect(c.state.doc.child(1).type, 'codeBlock');
      expect(c.state.doc.child(1).textContent, expected);
      expect(c.state.doc.blocks.last.textContent, 'gh');
      expect(c.state.selection.head, 5);
    });
  }

  testWidgets('an IME clear clears the whole cell before the caret', (
    tester,
  ) async {
    final c = controller([
      schema.node(
        'table',
        content: [
          schema.node(
            'tableRow',
            content: [
              schema.node(
                'tableCell',
                content: [paragraph('A'), paragraph('BCD')],
              ),
            ],
          ),
        ],
      ),
    ], position: 9);
    final key = await mount(tester, c);
    await imeClear(tester, key.currentState!);
    final cell = c.state.doc.child(0).child(0).child(0);
    expect(cell.childCount, 1);
    expect(cell.textContent, 'D');
  });

  testWidgets('an IME clear keeps the structure holding the caret', (
    tester,
  ) async {
    ft.Node text(String value) => schema.node('text', text: value);
    final quote = controller([
      schema.node(
        'blockquote',
        content: [
          paragraph('A'),
          schema.node(
            'heading',
            attrs: const {'level': 2},
            content: [text('BCD')],
          ),
        ],
      ),
    ], position: 7);
    var key = await mount(tester, quote);
    await imeClear(tester, key.currentState!);
    expect(quote.state.doc.child(0).childCount, 1);
    expect(quote.state.doc.child(0).child(0).type, 'heading');
    expect(quote.state.doc.child(0).textContent, 'D');
    expect(quote.state.selection.head, 2);

    ft.Node task(bool checked, String value) => schema.node(
      'taskItem',
      attrs: {'checked': checked},
      content: [paragraph(value)],
    );
    final tasks = controller([
      schema.node('taskList', content: [task(false, 'A'), task(true, 'BCD')]),
    ], position: 10);
    key = await mount(tester, tasks);
    await imeClear(tester, key.currentState!);
    expect(tasks.state.doc.child(0).childCount, 1);
    expect(tasks.state.doc.child(0).child(0).attrs['checked'], true);
    expect(tasks.state.doc.child(0).textContent, 'D');

    ft.Node item(List<ft.Node> content) =>
        schema.node('listItem', content: content);
    final nested = controller([
      schema.node(
        'bulletList',
        content: [
          item([
            paragraph('x'),
            schema.node(
              'orderedList',
              content: [
                item([paragraph('y')]),
                item([paragraph('BCD')]),
              ],
            ),
          ]),
        ],
      ),
    ], position: 15);
    key = await mount(tester, nested);
    await imeClear(tester, key.currentState!);
    final outer = nested.state.doc.child(0).child(0);
    expect(outer.child(0).textContent, '');
    expect(outer.child(1).childCount, 1);
    expect(outer.child(1).textContent, 'D');
  });

  for (final (name, blocks, anchor, head, expected, caret) in [
    ('a multi-block selection', ['abc', 'def'], 2, 7, ['bc', 'def'], 1),
    ('a selection in one block', ['abcd', 'ef'], 2, 4, ['bcd', 'ef'], 1),
    ('a selection from the start', ['abc', 'def'], 1, 7, ['abc', 'def'], 1),
  ]) {
    testWidgets('an IME clear keeps $name and what follows', (tester) async {
      final c = controller([for (final b in blocks) paragraph(b)]);
      final key = await mount(tester, c);
      c.setSelection(ft.TextSelection(anchor, head));
      await tester.pump();
      await imeClear(tester, key.currentState!);
      expect([for (final b in c.state.doc.blocks) b.textContent], expected);
      expect(c.state.selection.from, caret);
      expect(c.state.selection.to, caret);
    });
  }

  testWidgets('an IME clear with everything selected only collapses it', (
    tester,
  ) async {
    final c = controller([paragraph('ab'), paragraph('cd')]);
    final key = await mount(tester, c);
    c.exec('selectAll');
    await tester.pump();
    await imeClear(tester, key.currentState!);
    expect([for (final b in c.state.doc.blocks) b.textContent], ['ab', 'cd']);
    expect(c.state.selection.head, 1);
  });

  testWidgets('undo restores what an IME clear removed right after typing', (
    tester,
  ) async {
    final c = controller([paragraph('')]);
    final key = await mount(tester, c);
    await delta(tester, key, text: 'abc');
    await imeClear(tester, key.currentState!);
    expect(c.state.doc.blocks.first.textContent, '');
    c.exec('undo');
    await tester.pump();
    expect(c.state.doc.blocks.first.textContent, 'abc');
  });

  testWidgets('an IME clear in a table cell stops at the cell', (tester) async {
    ft.Node cell(String text) =>
        schema.node('tableCell', content: [paragraph(text)]);
    final c = controller([
      schema.node(
        'table',
        content: [
          schema.node('tableRow', content: [cell('ab'), cell('cd')]),
        ],
      ),
    ], position: 11);
    final key = await mount(tester, c);
    await imeClear(tester, key.currentState!);
    expect(c.state.doc.child(0).textContent, 'abd');
    expect(c.state.selection.head, 10);
  });

  for (final (name, blocks, position, expected) in [
    ('the end of the document', ['ab', 'cd'], 7, ['']),
    ('the start of a block', ['ab', 'cd'], 5, ['cd']),
    ('the middle of a block', ['ab', 'cd'], 6, ['d']),
    ('an empty block', ['ab', ''], 5, ['']),
    ('the end of a middle block', ['ab', 'cd', 'ef'], 7, ['', 'ef']),
  ]) {
    testWidgets('an IME clear deletes everything before $name', (tester) async {
      final c = controller([
        for (final block in blocks) paragraph(block),
      ], position: position);
      final key = await mount(tester, c);
      final state = key.currentState!;
      await imeClear(tester, state);
      expect([
        for (final block in c.state.doc.blocks) block.textContent,
      ], expected);
      expect(c.state.selection.head, 1);
      expect(state.debugInputValue.selection.extentOffset, 1);
    });
  }

  testWidgets('a delete spanning the window without select-all keeps blocks', (
    tester,
  ) async {
    final c = controller([paragraph('ab'), paragraph('cd')], position: 6);
    final key = await mount(tester, c);
    await delta(tester, key, from: 0, to: 3, caret: 0);
    expect(c.state.doc.childCount, 2);
    expect(c.state.doc.blocks.first.textContent, 'ab');
    expect(c.state.doc.blocks.last.textContent, '');
  });

  testWidgets('composition heading rule fires only on commit', (tester) async {
    final c = controller([paragraph('')]);
    final key = await mount(tester, c);
    await delta(
      tester,
      key,
      text: '## ',
      composing: const TextRange(start: 1, end: 4),
    );
    expect(c.state.doc.blocks.first.type, 'paragraph');
    key.currentState!.debugApplyDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: key.currentState!.debugInputValue.text,
        selection: const TextSelection.collapsed(offset: 4),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pump();
    expect(c.state.doc.blocks.first.type, 'heading');
    c.exec('undo');
    await tester.pump();
    expect(c.state.doc.blocks.first.textContent, '');
  });

  testWidgets(
    'sentinel deletion joins blocks and cross-block placeholder replaces selection',
    (tester) async {
      final c = controller([paragraph('ab'), paragraph('cd')], position: 5);
      final key = await mount(tester, c);
      await delta(tester, key, from: 0, to: 1, caret: 0);
      expect(c.state.doc.childCount, 1);
      expect(c.state.doc.blocks.first.textContent, 'abcd');
      c.replaceDocument(
        schema.node('doc', content: [paragraph('abc'), paragraph('def')]),
      );
      c.setSelection(const ft.TextSelection(2, 8));
      await tester.pump();
      expect(key.currentState!.debugInputValue.text, '\u200b\ufffc');
      await delta(tester, key, from: 1, to: 2, text: '中');
      expect(c.state.doc.blocks.first.textContent, 'a中f');
    },
  );

  testWidgets(
    'reversed long selection beside a surrogate pair replaces its entire range',
    (tester) async {
      final text = '😀${List.filled(2047, 'a').join()}';
      final c = controller([paragraph(text)]);
      final key = await mount(tester, c);
      c.setSelection(ft.TextSelection(text.length + 1, 3));
      await tester.pump();
      await delta(tester, key, text: 'X');
      expect(c.state.doc.child(0).textContent, '😀X');
      expect(c.state.selection, const ft.TextSelection(4));
    },
  );

  testWidgets(
    'long input is windowed and editing retains surrounding document text',
    (tester) async {
      final text = List.filled(10000, '中').join();
      final c = controller([paragraph(text)], position: 5001);
      final key = await mount(tester, c);
      expect(
        key.currentState!.debugInputValue.text.length,
        lessThanOrEqualTo(2049),
      );
      await delta(tester, key, text: 'X');
      expect(
        c.state.doc.blocks.first.textContent,
        '${text.substring(0, 5000)}X${text.substring(5000)}',
      );
      expect(
        key.currentState!.debugInputValue.text.length,
        lessThanOrEqualTo(2049),
      );
    },
  );

  testWidgets(
    '1M doc: 100 actual platform deltas only lay out the edited block',
    (tester) async {
      final doc = generateLargeDocument(1000000);
      final c = ft.TiptapController(doc: doc);
      final key = await mount(tester, c);
      final scans = c.diagnostics.fullDocumentScans;
      final stable = {
        for (var i = 1; i < min(doc.childCount, 30); i++)
          doc.blocks[i]: c.diagnostics.layoutsFor(doc.blocks[i]),
      };
      var blockLayouts = c.diagnostics.blockLayouts;
      for (var i = 0; i < 100; i++) {
        await delta(tester, key, text: 'x');
        expect(
          c.diagnostics.blockLayouts - blockLayouts,
          1,
          reason: 'delta $i',
        );
        blockLayouts = c.diagnostics.blockLayouts;
        expect(c.diagnostics.fullDocumentScans, scans);
        for (final entry in stable.entries) {
          expect(c.diagnostics.layoutsFor(entry.key), entry.value);
        }
      }
      expect(c.state.doc.blocks.summary.textLength, 1000100);
      expect(c.diagnostics.visibleBlocks, lessThan(50));
    },
  );

  testWidgets('50k paragraph edits reuse all untouched paragraph chunks', (
    tester,
  ) async {
    final c = controller([
      paragraph(List.filled(10000, 'word ').join()),
    ], position: 18001);
    final key = await mount(tester, c);
    final before = c.diagnostics.paragraphLayouts;
    await delta(tester, key, text: 'X');
    expect(c.diagnostics.paragraphLayouts - before, 1);
    expect(c.state.doc.blocks.summary.textLength, 50001);
  });

  testWidgets(
    'keyboard shortcuts, grapheme deletion, selection and clipboard',
    (tester) async {
      final c = controller([paragraph('ab😀')], position: 5);
      final key = await mount(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, 'ab');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await delta(tester, key, text: 'X');
      expect(c.toolbar.value.activeMarks, contains('bold'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(c.selectedText, 'X');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(c.state.doc.childCount, 2);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    'mouse click drag, word selection and readOnly keep IME disconnected',
    (tester) async {
      final c = controller([paragraph('hello world')]);
      final key = await mount(tester, c, readOnly: true);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      final rect = tester.getRect(find.byType(ft.TiptapEditor));
      final start =
          rect.topLeft + key.currentState!.geometry!.caretRect(1).center;
      final end =
          rect.topLeft + key.currentState!.geometry!.caretRect(6).center;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(start);
      await mouse.moveTo(end);
      await mouse.up();
      await tester.pump();
      expect(c.selectedText, 'hello');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, 'hello world');
      key.currentState!.debugApplyDeltas([
        TextEditingDeltaInsertion(
          oldText: key.currentState!.debugInputValue.text,
          textInserted: 'X',
          insertionOffset: 1,
          selection: const TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);
      expect(c.state.doc.blocks.first.textContent, 'hello world');
      expect(tester.testTextInput.hasAnyClients, isFalse);
    },
  );

  testWidgets(
    'touch long press shows magnifier, handles and host context menu',
    (tester) async {
      final c = controller([paragraph('hello world')]);
      final key = await mount(
        tester,
        c,
        menu: (_, details) => Positioned(
          left: 10,
          top: 10,
          child: CupertinoButton(
            onPressed: details.copy,
            child: const Text('Host copy'),
          ),
        ),
      );
      final target =
          tester.getTopLeft(find.byType(ft.TiptapEditor)) +
          key.currentState!.geometry!.caretRect(3).center;
      final touch = await tester.startGesture(target);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(RawMagnifier), findsOneWidget);
      expect(c.selectedText, 'hello');
      await touch.up();
      await tester.pump();
      expect(find.text('Host copy'), findsOneWidget);
    },
  );

  testWidgets('select all from the menu keeps the menu open', (tester) async {
    final c = controller([for (var i = 0; i < 60; i++) paragraph('line $i')]);
    final key = await mount(
      tester,
      c,
      menu: (_, details) => Positioned(
        left: 10,
        top: 10,
        child: CupertinoButton(
          onPressed: details.selectAll,
          child: Text(details.copy == null ? 'Select only' : 'Has copy'),
        ),
      ),
    );
    await tester.longPressAt(
      tester.getTopLeft(find.byType(ft.TiptapEditor)) +
          key.currentState!.geometry!.caretRect(3).center,
    );
    await tester.pump();
    final scroll = key.currentState!.scrollController.offset;
    await tester.tap(find.text('Has copy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.state.selection, isA<ft.AllSelection>());
    expect(find.text('Has copy'), findsOneWidget);
    expect(key.currentState!.scrollController.offset, scroll);
  });

  testWidgets('select all is offered only while text is left to select', (
    tester,
  ) async {
    Future<GlobalKey<ft.TiptapEditorState>> pressFirstWord(
      ft.TiptapController c,
    ) async {
      final key = await mount(
        tester,
        c,
        menu: (_, details) => Positioned(
          left: 10,
          top: 10,
          child: CupertinoButton(
            onPressed: details.selectAll,
            child: Text(details.selectAll == null ? 'All' : 'Partial'),
          ),
        ),
      );
      await tester.longPressAt(
        tester.getTopLeft(find.byType(ft.TiptapEditor)) +
            key.currentState!.geometry!.caretRect(3).center,
      );
      await tester.pump();
      return key;
    }

    await pressFirstWord(controller([paragraph('hello world')]));
    expect(find.text('Partial'), findsOneWidget);
    await tester.tap(find.text('Partial'));
    await tester.pump();
    expect(find.text('All'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pressFirstWord(controller([paragraph('hello')]));
    expect(find.text('All'), findsOneWidget);
  });

  for (final (platform, collapses) in [
    (TargetPlatform.android, true),
    (TargetPlatform.iOS, false),
  ]) {
    testWidgets(
      'a menu copy on $platform ${collapses ? 'ends' : 'keeps'} the selection',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final c = controller([paragraph('hello world')]);
        final key = await mount(
          tester,
          c,
          menu: (_, details) => Positioned(
            left: 10,
            top: 10,
            child: CupertinoButton(
              onPressed: details.copy,
              child: const Text('Copy'),
            ),
          ),
        );
        c.setSelection(const ft.TextSelection(1, 6));
        await tester.pump();
        final press = await tester.startGesture(
          tester.getTopLeft(find.byType(ft.TiptapEditor)) +
              key.currentState!.geometry!.caretRect(3).center,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await press.up();
        await tester.pump();
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsNothing);
        expect(c.state.selection.empty, collapses);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  group('menu actions', () {
    late String? clipboard;

    Future<ft.TiptapController> openMenu(
      WidgetTester tester, {
      bool readOnly = false,
    }) async {
      clipboard = 'pasted';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData' && clipboard != null
            ? {'text': clipboard}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = controller([paragraph('hello world')]);
      final key = await mount(
        tester,
        c,
        readOnly: readOnly,
        menu: (_, details) => Positioned(
          left: 10,
          top: 10,
          child: Row(
            children: [
              if (details.copy case final copy?)
                CupertinoButton(onPressed: copy, child: const Text('Copy')),
              if (details.paste case final paste?)
                CupertinoButton(onPressed: paste, child: const Text('Paste')),
              if (details.selectAll case final selectAll?)
                CupertinoButton(
                  onPressed: selectAll,
                  child: const Text('Select all'),
                ),
              const Text('Menu', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );
      await tester.longPressAt(
        tester.getTopLeft(find.byType(ft.TiptapEditor)) +
            key.currentState!.geometry!.caretRect(3).center,
      );
      await tester.pump();
      return c;
    }

    testWidgets('paste replaces the selection and closes the menu', (
      tester,
    ) async {
      final c = await openMenu(tester);
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(c.state.doc.textContent, 'pasted world');
      expect(c.state.selection.empty, isTrue);
      expect(find.text('Menu'), findsNothing);
    });

    testWidgets('paste with an empty clipboard still closes the menu', (
      tester,
    ) async {
      final c = await openMenu(tester);
      clipboard = null;
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(c.state.doc.textContent, 'hello world');
      expect(find.text('Menu'), findsNothing);
    });

    testWidgets('select all keeps the menu and then copy ends it', (
      tester,
    ) async {
      final c = await openMenu(tester);
      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(c.state.selection, isA<ft.AllSelection>());
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Select all'), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(c.state.selection.empty, isTrue);
      expect(c.state.selection.from, c.state.doc.content.size - 1);
      expect(find.text('Menu'), findsNothing);
    });

    testWidgets('read-only text offers no paste and copy still works', (
      tester,
    ) async {
      final c = await openMenu(tester, readOnly: true);
      expect(find.text('Paste'), findsNothing);
      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(c.state.selection, isA<ft.AllSelection>());
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(c.state.selection.empty, isTrue);
      expect(find.text('Menu'), findsNothing);
    });
  });

  testWidgets('deleting the selection closes the menu', (tester) async {
    final c = controller([paragraph('hello world')]);
    final key = await mount(
      tester,
      c,
      menu: (_, details) => const Positioned(
        left: 10,
        top: 10,
        child: Text('Menu', textDirection: TextDirection.ltr),
      ),
    );
    await tester.longPressAt(
      tester.getTopLeft(find.byType(ft.TiptapEditor)) +
          key.currentState!.geometry!.caretRect(3).center,
    );
    await tester.pump();
    expect(find.text('Menu'), findsOneWidget);
    final selection = key.currentState!.debugInputValue.selection;
    expect(selection.isCollapsed, isFalse);
    await delta(
      tester,
      key,
      from: selection.start,
      to: selection.end,
      caret: selection.start,
    );
    await tester.pump();
    expect(find.text('Menu'), findsNothing);
  });

  test('height index replacements and lazy width invalidation preserve prefix sums', () {
    final nodes = List.generate(1000, (i) => paragraph('x' * (20 + i % 100)));
    const style = ft.TiptapEditorStyle();
    final heights = ft.TiptapHeightIndex(nodes, style: style, width: 400);
    heights.measure(400, 99);
    expect(heights.heightAt(400), closeTo(99, .000001));
    final offset = heights.offsetOf(401);
    expect(heights.indexAt(offset + .1), 401);
    heights.replace(100, 102, [paragraph('new')]);
    expect(heights.length, 999);
    expect(heights.heightAt(399), closeTo(99, .000001));
    heights.setWidth(200);
    expect(heights.heightAt(399), isNot(closeTo(99, .000001)));
    expect(
      heights.offsetOf(heights.length),
      closeTo(heights.totalHeight, .000001),
    );
  });

  testWidgets(
    'controller JSON, local toolbar and onChanged do not serialize per edit',
    (tester) async {
      var changes = 0;
      final c = ft.TiptapController(
        doc: schema.node('doc', content: [paragraph('a')]),
        onChanged: (_) => changes++,
      );
      c.exec('insertText', {'text': 'X'});
      expect(changes, 0);
      await tester.pump();
      expect(changes, 1);
      c.setSelection(const ft.TextSelection(1));
      expect(changes, 1);
      expect(jsonDecode(c.json), c.state.doc.toJson());
      c.dispose();
    },
  );
  testWidgets(
    'soft Backspace undoes an input rule and later deltas in a batch are retained',
    (tester) async {
      final c = controller([paragraph('')]);
      final key = await mount(tester, c);
      await delta(tester, key, text: '**x**');
      expect(c.state.doc.blocks.first.textContent, 'x');
      await delta(tester, key, from: 1, to: 2, caret: 1);
      expect(c.state.doc.blocks.first.textContent, '**x**');
      c.replaceDocument(schema.node('doc', content: [paragraph('')]));
      await tester.pump();
      key.currentState!.debugApplyDeltas([
        const TextEditingDeltaInsertion(
          oldText: '\u200b',
          textInserted: '## ',
          insertionOffset: 1,
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
        const TextEditingDeltaInsertion(
          oldText: '\u200b## ',
          textInserted: '中',
          insertionOffset: 4,
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange.empty,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(c.state.doc.blocks.first.type, 'heading');
      expect(c.state.doc.blocks.first.textContent, '中');
      expect(c.state.selection.head, 2);
    },
  );

  testWidgets(
    'resizing retains the first visible block and invalidates width lazily',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = generateLargeDocument(1000000),
          c = ft.TiptapController(doc: generateLargeDocument(1000000));
      final key = await mount(tester, c, autofocus: false);
      key.currentState!.scrollController.jumpTo(40000);
      await tester.pump();
      await tester.pump();
      final geometry = key.currentState!.geometry!;
      final index = doc.blocks.indexAt(
        geometry.positionForOffset(const Offset(20, 1)),
      );
      final position = doc.blocks.positionAt(index) + 1;
      final y = geometry.caretRect(position).top,
          scans = c.diagnostics.fullDocumentScans;
      tester.view.physicalSize = const Size(500, 600);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        doc.blocks.indexAt(geometry.positionForOffset(const Offset(20, 1))),
        index,
      );
      expect(geometry.caretRect(position).top, closeTo(y, .5));
      expect(c.diagnostics.fullDocumentScans, scans);
    },
  );

  testWidgets('caret reveal follows selection and keyboard insets', (
    tester,
  ) async {
    final c = ft.TiptapController(doc: generateLargeDocument(1000000));
    final key = await mount(tester, c);
    final index = c.state.doc.childCount ~/ 2;
    final position = c.state.doc.blocks.positionAt(index) + 1;
    c.setSelection(ft.TextSelection(position));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    var rect = key.currentState!.geometry!.caretRect(position);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(577));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 250 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    rect = key.currentState!.geometry!.caretRect(position);
    expect(rect.bottom, lessThanOrEqualTo(327));
  });

  testWidgets(
    'caret reveal leaves a visible caret alone and glides to a hidden one',
    (tester) async {
      final c = controller([for (var i = 0; i < 60; i++) paragraph('line $i')]);
      final key = await mount(tester, c);
      final scroll = tester
          .widget<Scrollable>(
            find.descendant(
              of: find.byType(ft.TiptapEditor),
              matching: find.byType(Scrollable),
            ),
          )
          .controller!;
      double bottomOf(int index) => key.currentState!.geometry!
          .caretRect(c.state.doc.blocks.positionAt(index) + 1)
          .bottom;
      tester.view.viewInsets = FakeViewPadding(
        bottom: 250 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      // The caret only has to clear the keyboard by the 24 px margin.
      final limit =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
          250 -
          24;
      var visible = 0;
      while (bottomOf(visible + 1) < limit) {
        visible++;
      }
      c.setSelection(
        ft.TextSelection(c.state.doc.blocks.positionAt(visible) + 1),
      );
      await tester.pump();
      await tester.pump();
      expect(scroll.offset, 0);

      final hidden = visible + 3;
      c.setSelection(
        ft.TextSelection(c.state.doc.blocks.positionAt(hidden) + 1),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scroll.offset, greaterThan(0));
      expect(bottomOf(hidden), greaterThan(limit));
      await tester.pump(const Duration(milliseconds: 250));
      expect(bottomOf(hidden), moreOrLessEquals(limit, epsilon: .5));
    },
  );

  testWidgets('switching read-only drops a range picked in the other mode', (
    tester,
  ) async {
    final c = controller([paragraph('hello world')]);
    var readOnly = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ft.TiptapEditor(
              controller: c,
              readOnly: readOnly,
              autofocus: true,
            );
          },
        ),
      ),
    );
    await tester.pump();
    c.setSelection(const ft.TextSelection(1, 6));
    await tester.pump();
    rebuild(() => readOnly = true);
    await tester.pump();
    await tester.pump();
    expect(c.state.selection.empty, isTrue);
    expect(c.state.selection.head, 6);

    c.setSelection(const ft.TextSelection(1, 6));
    await tester.pump();
    rebuild(() => readOnly = false);
    await tester.pump();
    await tester.pump();
    expect(c.state.selection.empty, isTrue);
  });

  testWidgets('wrapCodeBlocks wraps a long code line', (tester) async {
    final code = List.filled(40, 'token').join(' ');
    for (final wrap in [false, true]) {
      final c = controller([
        schema.node('codeBlock', content: [schema.node('text', text: code)]),
      ]);
      final key = await mount(
        tester,
        c,
        style: ft.TiptapEditorStyle(wrapCodeBlocks: wrap),
      );
      final geometry = key.currentState!.geometry!;
      final first = geometry.caretRect(1),
          last = geometry.caretRect(code.length + 1);
      expect(last.top > first.top, wrap);
    }
  });

  testWidgets('a viewport that shrinks while focused keeps the caret visible', (
    tester,
  ) async {
    final c = controller([for (var i = 0; i < 30; i++) paragraph('line $i')]);
    final key = GlobalKey<ft.TiptapEditorState>();
    var height = 600.0;
    late StateSetter resize;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
                child: ft.TiptapEditor(
                  key: key,
                  controller: c,
                  autofocus: true,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    var line = 0;
    while (key.currentState!.geometry!
            .caretRect(c.state.doc.blocks.positionAt(line + 1) + 1)
            .bottom <
        560) {
      line++;
    }
    final position = c.state.doc.blocks.positionAt(line) + 1;
    c.setSelection(ft.TextSelection(position));
    await tester.pump();
    await tester.pump();
    resize(() => height = 300);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      key.currentState!.geometry!.caretRect(position).bottom,
      lessThanOrEqualTo(300),
    );
  });

  testWidgets(
    'dragging the collapsed touch handle keeps a collapsed selection',
    (tester) async {
      final c = controller([paragraph('abcdefghijk')]);
      final key = await mount(tester, c);
      final global = tester.getTopLeft(find.byType(ft.TiptapEditor));
      await tester.tapAt(
        global + key.currentState!.geometry!.caretRect(2).center,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final handle = find
          .descendant(
            of: find.byType(ft.TiptapEditor),
            matching: find.byType(CustomPaint),
          )
          .last;
      final point = tester.getTopLeft(handle) + const Offset(22, 15);
      final touch = await tester.startGesture(point);
      await touch.moveBy(const Offset(90, 0));
      await tester.pump();
      expect(c.state.selection.empty, isTrue);
      expect(c.state.selection.head, greaterThan(2));
      await touch.up();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('macOS Cmd and Option shortcuts use the document selection', (
    tester,
  ) async {
    final c = controller([paragraph('hello world')], position: 12);
    final key = await mount(tester, c);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(c.state.selection.head, 7);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await delta(tester, key, text: 'X');
    expect(
      c.state.doc.blocks.first.content.any(
        (n) => n.marks.any((m) => m.type == 'bold'),
      ),
      isTrue,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(c.state.doc.blocks.first.textContent, 'hello world');
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('iOS sends geometry and shows the native context menu', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final c = controller([paragraph('hello world')]);
    final key = await mount(tester, c, systemMenu: true);
    final methods = tester.testTextInput.log.map((c) => c.method).toSet();
    expect(
      methods,
      containsAll([
        'TextInput.setEditableSizeAndTransform',
        'TextInput.setCaretRect',
        'TextInput.setMarkedTextRect',
        'TextInput.setSelectionRects',
        'TextInput.setStyle',
      ]),
    );
    final target =
        tester.getTopLeft(find.byType(ft.TiptapEditor)) +
        key.currentState!.geometry!.caretRect(3).center;
    await tester.longPressAt(target);
    await tester.pump();
    expect(
      calls.any((call) => call.method == 'ContextMenu.showSystemContextMenu'),
      isTrue,
    );
    expect(c.state.selection.empty, true);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets(
    'clipboard copy cut and multiline plain paste operate on model ranges',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = controller([paragraph('abc')]);
      await mount(tester, c);
      c.setSelection(const ft.TextSelection(2, 3));
      await tester.pump();
      Future<void> shortcut(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      await shortcut(LogicalKeyboardKey.keyC);
      expect(clipboard, 'b');
      await shortcut(LogicalKeyboardKey.keyX);
      expect(c.state.doc.blocks.first.textContent, 'ac');
      clipboard = 'x\n中';
      await shortcut(LogicalKeyboardKey.keyV);
      expect(c.state.doc.blocks.map((b) => b.textContent).toList(), [
        'ax',
        '中c',
      ]);
    },
  );
  testWidgets('text copied here keeps its formatting when the IME inserts it', (
    tester,
  ) async {
    final bold = schema.node(
      'paragraph',
      content: [
        schema.node('text', text: 'hi', marks: [schema.mark('bold')]),
      ],
    );
    final c = controller([bold, paragraph('')], position: 5);
    final key = await mount(tester, c);
    c.setSelection(const ft.TextSelection(1, 3));
    await c.copy(write: (_, _) async {});
    c.setSelection(const ft.TextSelection(5));
    await tester.pump();
    await delta(tester, key, text: 'hi');
    expect(c.state.doc.child(1).textContent, 'hi');
    expect(c.state.doc.child(1).content.first.marks.single.type, 'bold');
  });

  testWidgets('control shift V pastes without linking the selection', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'https://a.b'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final c = controller([paragraph('abc')]);
    await mount(tester, c);
    c.setSelection(const ft.TextSelection(1, 4));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(c.state.doc.textContent, 'https://a.b');
    expect(c.state.doc.child(0).content.first.marks, isEmpty);
  });
  testWidgets(
    'multi-line IME text uses a synchronous paste hook outside code',
    (tester) async {
      final c = controller([paragraph('')]);
      Map<String, dynamic> convert(String _) => {
        'type': 'doc',
        'content': [
          {
            'type': 'heading',
            'attrs': {'level': 2},
            'content': [
              {'type': 'text', 'text': 'T'},
            ],
          },
        ],
      };
      final key = await mount(tester, c, onPasteText: convert);
      await delta(tester, key, text: '## T\nbody');
      expect(c.state.doc.child(0).type, 'heading');
      c.replaceDocument(schema.node('doc', content: [paragraph('')]));
      c.insertCommittedLines('## T\nbody', (_) async => convert(''));
      expect(c.state.doc.blocks.map((b) => b.textContent).toList(), [
        '## T',
        'body',
      ]);
      c.replaceDocument(
        schema.node(
          'doc',
          content: [
            schema.node('codeBlock', content: [schema.node('text', text: 'x')]),
            paragraph(''),
          ],
        ),
      );
      c.setSelection(const ft.TextSelection(2));
      var calls = 0;
      c.insertCommittedLines('a\nb', (_) {
        calls++;
        return null;
      });
      expect(calls, 0);
    },
  );
  for (final (lineEndings, text) in [
    ('LF', 'value\n\n\nnext'),
    ('CRLF and CR', 'value\r\n\r\n\rnext'),
  ]) {
    testWidgets(
      'IME clipboard $lineEndings stays literal in code with one undo',
      (tester) async {
        final c = controller([schema.node('codeBlock')]);
        final key = await mount(tester, c);
        final before = c.state;
        await delta(tester, key, text: text);
        expect(c.state.doc.child(0).type, 'codeBlock');
        expect(c.state.doc.child(0).textContent, 'value\n\n\nnext');
        expect(c.state.selection, const ft.TextSelection(13));
        expect(c.state.doc.childCount, 2);
        expect(c.state.doc.child(1).textContent, isEmpty);
        final pasted = c.state;
        c.exec('undo');
        expect(c.state.doc.toJson(), before.doc.toJson());
        expect(c.state.selection, before.selection);
        expect(c.state.history.canUndo, isFalse);
        c.exec('redo');
        expect(c.state.doc.toJson(), pasted.doc.toJson());
        expect(c.state.selection, pasted.selection);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets('iOS floating cursor retains its final caret on end', (
    tester,
  ) async {
    final c = controller([paragraph('abcdefghijk')]);
    final key = await mount(tester, c);
    final client =
        (tester.testTextInput.log
                        .lastWhere(
                          (call) => call.method == 'TextInput.setClient',
                        )
                        .arguments
                    as List)
                .first
            as int;
    Future<void> cursor(String state, double x) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.updateFloatingCursor', [
            client,
            'FloatingCursorDragState.$state',
            {'X': x, 'Y': 0.0},
          ]),
        ),
        (_) {},
      );
      await tester.pump();
    }

    await cursor('start', 0);
    await cursor('update', 80);
    final position = c.state.selection.head;
    expect(position, greaterThan(1));
    await cursor('end', 0);
    expect(c.state.selection.head, position);
    expect(key.currentState!.debugInputValue.selection.extentOffset, position);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  testWidgets('composition owns arrows and deletion until the IME commits', (
    tester,
  ) async {
    final c = controller([paragraph('')]);
    final key = await mount(tester, c);
    await delta(
      tester,
      key,
      text: 'n',
      composing: const TextRange(start: 1, end: 2),
    );
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.backspace,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(c.state.doc.childCount, 1);
      expect(c.state.doc.blocks.first.textContent, 'n');
      expect(c.state.selection.head, 2);
      expect(c.composing.isCollapsed, isFalse);
    }
    key.currentState!.debugApplyDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: key.currentState!.debugInputValue.text,
        selection: const TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await delta(tester, key, text: '\n');
    await tester.pump();
    expect(c.state.doc.childCount, 2);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  testWidgets('Enter and IME typing leave a selected atom intact', (
    tester,
  ) async {
    final atom = schema.fromJson({
      'type': 'horizontalRule',
      'attrs': {'variant': 'solid', 'label': null},
    });
    final c = controller([atom, paragraph('tail')], position: 2);
    final key = await mount(tester, c);
    c.setSelection(ft.NodeSelection(c.state.doc, 0));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, character: '\n');
    await delta(tester, key, text: '\n');
    await tester.pump();
    expect(c.state.doc.blocks.first, same(atom));
    expect(c.state.doc.childCount, 3);
    c.setSelection(ft.NodeSelection(c.state.doc, 0));
    await tester.pump();
    await delta(tester, key, from: 1, to: 2, text: '中');
    expect(c.state.doc.blocks.first, same(atom));
    expect(c.state.doc.blocks[1].textContent, '中');
  });
  testWidgets('equivalent host styles retain caches across parent rebuilds', (
    tester,
  ) async {
    final c = ft.TiptapController(doc: generateLargeDocument(1000000));
    addTearDown(c.dispose);
    final key = GlobalKey<ft.TiptapEditorState>();
    late StateSetter rebuild;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ft.TiptapEditor(
              key: key,
              controller: c,
              style: ft.TiptapEditorStyle(
                headings: List.of(const ft.TiptapEditorStyle().headings),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final scans = c.diagnostics.fullDocumentScans,
        layouts = c.diagnostics.paragraphLayouts;
    rebuild(() {});
    await tester.pump();
    await tester.pump();
    expect(c.diagnostics.fullDocumentScans, scans);
    expect(c.diagnostics.paragraphLayouts, layouts);
  });
}
