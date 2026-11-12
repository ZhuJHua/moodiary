import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

final _schema = ft.Schema.standard();
ft.Node _p(String text) => _schema.node(
  'paragraph',
  content: [if (text.isNotEmpty) _schema.node('text', text: text)],
);
ft.TiptapController _doc(List<ft.Node> blocks) =>
    ft.TiptapController(doc: _schema.node('doc', content: blocks));
const _mobile = TargetPlatformVariant({
  TargetPlatform.iOS,
  TargetPlatform.android,
});

Future<ft.TiptapEditorState> _mount(
  WidgetTester tester,
  ft.TiptapController c, {
  bool readOnly = false,
  GlobalKey? boundary,
  ValueChanged<String>? open,
}) async {
  addTearDown(c.dispose);
  await tester.pumpWidget(
    CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          height: 480,
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: const Color(0xffffffff),
              child: ft.TiptapEditor(
                controller: c,
                autofocus: !readOnly,
                readOnly: readOnly,
                onReferenceTap: open,
                style: const ft.TiptapEditorStyle(wrapCodeBlocks: false),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return tester.state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor));
}

Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  for (final type in [
    'horizontalRule',
    'image',
    'video',
    'audio',
    'attachment',
  ]) {
    ft.Node atom() => _schema.node(
      type,
      attrs: type == 'horizontalRule' ? null : {'src': 'fixture'},
    );
    test(
      '$type selected typing reuses empty paragraph and undo restores object',
      () {
        final c = _doc([atom(), _p('')]);
        addTearDown(c.dispose);
        c.setSelection(ft.NodeSelection(c.state.doc, 0));
        c.exec('insertText', {'text': 'X'});
        expect(c.state.doc.childCount, 2);
        expect(c.state.doc.child(0).type, type);
        expect(c.state.doc.child(1).textContent, 'X');
        c.exec('undo');
        expect(c.state.selection, isA<ft.NodeSelection>());
        expect(c.state.doc.childCount, 2);
        c.exec('redo');
        expect(c.state.selection, const ft.TextSelection(3));
      },
    );
    for (final backward in [true, false]) {
      test(
        '$type adjacent ${backward ? 'Backspace' : 'Delete'} follows protective policy',
        () {
          final c = _doc([_p('ab'), atom(), _p('cd')]);
          addTearDown(c.dispose);
          final selection = ft.TextSelection(backward ? 6 : 3);
          c.setSelection(selection);
          final before = c.state.doc;
          final command = backward ? 'deleteBackward' : 'deleteForward';
          c.exec(command);
          if (type != 'horizontalRule') {
            expect(c.state.doc, same(before));
            expect(c.state.selection, isA<ft.NodeSelection>());
            c.exec(command);
          }
          expect(c.state.doc.childCount, 2);
          c.exec('undo');
          expect(c.state.doc.toJson(), before.toJson());
          expect(
            c.state.selection,
            type == 'horizontalRule' ? selection : isA<ft.NodeSelection>(),
          );
        },
      );
    }
    testWidgets('$type Up exits object; singleton arrows expose both gaps', (
      tester,
    ) async {
      final c = _doc([atom()]);
      final state = await _mount(tester, c);
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
      ]) {
        c.setSelection(ft.NodeSelection(c.state.doc, 0));
        await tester.sendKeyEvent(key);
        final before =
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowUp;
        expect(c.state.selection, isA<ft.GapSelection>());
        expect(c.state.selection.head, before ? 0 : 1);
        final rect = state.geometry!.caretRect(c.state.selection.head);
        expect(rect.height, 2);
        expect(rect.width, 20);
      }
      await _unmount(tester);
    }, variant: _mobile);
    for (final before in [true, false]) {
      test('$type ${before ? 'before' : 'after'} gap types in same cell', () {
        final c = _doc([
          _schema.node(
            'table',
            content: [
              _schema.node(
                'tableRow',
                content: [
                  _schema.node('tableCell', content: [atom()]),
                  _schema.node('tableCell', content: [_p('other')]),
                ],
              ),
            ],
          ),
        ]);
        addTearDown(c.dispose);
        c.setSelection(ft.GapSelection(before ? 3 : 4));
        c.exec('insertText', {'text': 'X'});
        final cell = c.state.doc.child(0).child(0).child(0);
        expect(cell.childCount, 2);
        expect(cell.child(before ? 0 : 1).textContent, 'X');
        expect(cell.child(before ? 1 : 0).type, type);
        expect(c.state.doc.child(0).child(0).child(1).textContent, 'other');
      });
    }
  }

  testWidgets(
    'non-composing mobile arrows cross paragraphs once and respect composition',
    (tester) async {
      final c = _doc([_p('ab'), _p('cd')]);
      await _mount(tester, c);
      c.setSelection(const ft.TextSelection(5));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), true);
      expect(c.state.selection, const ft.TextSelection(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(c.state.selection, const ft.TextSelection(5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(c.state.selection.head, lessThan(4));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(c.state.selection.head, greaterThan(4));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '\u200bcd',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 3),
        ),
      );
      await tester.pump();
      final selection = c.state.selection;
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), false);
      expect(c.state.selection, selection);
      await _unmount(tester);
    },
    variant: _mobile,
  );

  testWidgets(
    'divider ordinary taps choose nearest caret and keep IME; read tap inert',
    (tester) async {
      final c = _doc([_schema.node('horizontalRule')]);
      final state = await _mount(tester, c);
      final rect = state.geometry!.rowRect(0);
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();
      expect(c.state.selection, const ft.GapSelection(0));
      expect(tester.testTextInput.hasAnyClients, true);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 2));
      await tester.pump(const Duration(milliseconds: 450));
      expect(c.state.selection, const ft.GapSelection(1));
      await _unmount(tester);
      final read = _doc([_schema.node('horizontalRule')]);
      final readState = await _mount(tester, read, readOnly: true);
      final before = read.state.selection;
      await tester.tapAt(readState.geometry!.rowRect(0).center);
      expect(read.state.selection, before);
      await _unmount(tester);
    },
    variant: _mobile,
  );

  testWidgets('read-only explicit divider selection paints no outline', (
    tester,
  ) async {
    final c = _doc([_schema.node('horizontalRule')]);
    final key = GlobalKey();
    c.setSelection(const ft.GapSelection(0));
    await _mount(tester, c, readOnly: true, boundary: key);
    Future<List<int>> pixels() async {
      await tester.pump();
      final bytes = await tester.runAsync(() async {
        final img =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        img.dispose();
        return data;
      });
      return bytes!.buffer.asUint8List();
    }

    final before = await pixels();
    c.setSelection(ft.NodeSelection(c.state.doc, 0));
    expect(await pixels(), before);
    await _unmount(tester);
  });

  testWidgets(
    'focused Apple hold moves caret; touch triple tap selects paragraph',
    (tester) async {
      final c = _doc([_p('hello world')]);
      final state = await _mount(tester, c);
      final point = state.geometry!.caretRect(3).center;
      await tester.longPressAt(point);
      expect(
        c.state.selection.empty,
        defaultTargetPlatform == TargetPlatform.iOS,
      );
      await _unmount(tester);
      final triple = _doc([_p('hello world')]);
      final tripleState = await _mount(tester, triple);
      final triplePoint = tripleState.geometry!.caretRect(3).center;
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(triplePoint);
        await tester.pump(const Duration(milliseconds: 70));
      }
      expect(
        [triple.state.selection.anchor, triple.state.selection.head],
        [1, 12],
      );
      await _unmount(tester);
    },
    variant: _mobile,
  );

  testWidgets(
    'editable reference chip places caret, double selects unit, modifier opens; read opens',
    (tester) async {
      final chip = _schema.node(
        'diaryLink',
        attrs: {'id': 'd1', 'label': 'Diary'},
      );
      final opens = <String>[];
      final c = _doc([
        _schema.node(
          'paragraph',
          content: [
            _schema.node('text', text: 'a'),
            chip,
            _schema.node('text', text: 'z'),
          ],
        ),
      ]);
      final state = await _mount(tester, c, open: opens.add);
      final boxes = state.geometry!.selectionRects(2, 3);
      final point = boxes.first.center;
      await tester.tapAt(point);
      expect(opens, isEmpty);
      await tester.tapAt(point);
      expect(c.state.selection, const ft.TextSelection(2, 3));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapAt(point);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(opens, ['d1']);
      await _unmount(tester);
      final read = _doc([
        _schema.node('paragraph', content: [chip]),
      ]);
      final r = await _mount(tester, read, readOnly: true, open: opens.add);
      await tester.tapAt(r.geometry!.selectionRects(1, 2).first.center);
      expect(opens, ['d1', 'd1']);
      await _unmount(tester);
    },
  );

  test(
    'code indent/outdent selected lines maps reversed selection and undo',
    () {
      final c = _doc([
        _schema.node(
          'codeBlock',
          content: [_schema.node('text', text: 'a\n  b\nc')],
        ),
      ]);
      addTearDown(c.dispose);
      c.setSelection(const ft.TextSelection(6, 1));
      c.exec('tab');
      expect(c.state.doc.textContent, '  a\n    b\nc');
      expect(c.state.selection.anchor, greaterThan(c.state.selection.head));
      c.exec('shiftTab');
      expect(c.state.doc.textContent, 'a\n  b\nc');
      c.exec('undo');
      expect(c.state.doc.textContent, '  a\n    b\nc');
    },
  );
  for (final command in ['splitBlock', 'hardBreak']) {
    test(
      'code $command preserves indentation and exits on the third Enter',
      () {
        final c = _doc([
          _schema.node(
            'codeBlock',
            content: [_schema.node('text', text: '  foo')],
          ),
        ]);
        addTearDown(c.dispose);
        c.setSelection(const ft.TextSelection(6));
        c.exec(command);
        expect(c.state.doc.textContent, '  foo\n  ');
        c.exec(command);
        final beforeExit = c.state;
        expect(c.state.doc.child(0).textContent, '  foo\n  \n  ');
        c.exec(command);
        expect(c.state.doc.childCount, 3);
        expect(c.state.doc.child(0).type, 'codeBlock');
        expect(c.state.doc.child(0).textContent, '  foo');
        expect(c.state.doc.child(1).type, 'paragraph');
        expect(c.state.selection, const ft.TextSelection(8));
        c.exec('undo');
        expect(c.state.doc.toJson(), beforeExit.doc.toJson());
        expect(c.state.selection, beforeExit.selection);
        c.exec('exitCode');
        expect(c.state.doc.childCount, 2);
        expect(c.state.doc.child(0).textContent, '  foo\n  \n  ');
        expect(c.state.doc.child(1).type, 'paragraph');
      },
    );
  }

  testWidgets(
    'mouse word/paragraph drags retain granularity and never pan wide code; Shift-wheel and trackpad pan scroll',
    (tester) async {
      final text = List.filled(30, 'hello world again ').join();
      final c = _doc([
        _schema.node('codeBlock', content: [_schema.node('text', text: text)]),
        _p('tail'),
      ]);
      final state = await _mount(tester, c);
      final g = state.geometry!;
      final point = g.caretRect(3).center;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: point);
      await mouse.down(point);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 80));
      await mouse.down(point);
      await mouse.moveTo(g.caretRect(9).center);
      expect(c.selectedText, 'hello world');
      await mouse.up();
      expect(g.horizontalScrollMetrics(0)!.offset, 0);
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 2; i++) {
        await mouse.down(point);
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 80));
      }
      await mouse.down(point);
      await mouse.moveTo(g.caretRect(c.state.doc.child(0).nodeSize + 2).center);
      expect(c.state.selection.to, c.state.doc.content.size - 1);
      await mouse.up();
      c.setSelection(const ft.TextSelection(1));
      await tester.pumpAndSettle();
      final offset = g.horizontalScrollMetrics(0)!.offset;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: point, scrollDelta: const Offset(0, 70)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(g.horizontalScrollMetrics(0)!.offset, offset + 70);
      final trackpad = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await trackpad.panZoomStart(point);
      await trackpad.panZoomUpdate(point, pan: const Offset(-50, 0));
      await trackpad.panZoomEnd();
      await tester.pump();
      expect(g.horizontalScrollMetrics(0)!.offset, greaterThan(offset + 70));
      await mouse.removePointer();
      await _unmount(tester);
    },
  );

  testWidgets(
    'Page movement uses viewport caret on Windows and scroll on Apple; Home follows platform',
    (tester) async {
      final c = _doc([for (var i = 0; i < 100; i++) _p('line $i')]);
      final state = await _mount(tester, c);
      c.setSelection(const ft.TextSelection(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      final apple = defaultTargetPlatform == TargetPlatform.macOS;
      expect(c.state.selection.head, apple ? 3 : greaterThan(3));
      if (apple) expect(state.scrollController.offset, greaterThan(100));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      if (apple) {
        expect(c.state.selection.head, 3);
        expect(state.scrollController.offset, 0);
      } else {
        expect(
          c.state.selection.head,
          state.geometry!.lineBoundary(c.state.selection.head).start,
        );
      }
      await _unmount(tester);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'mobile code hardware Tab, Shift Enter and Mod Enter have one route',
    (tester) async {
      final c = _doc([
        _schema.node(
          'codeBlock',
          content: [_schema.node('text', text: '  foo')],
        ),
      ]);
      await _mount(tester, c);
      c.setSelection(const ft.TextSelection(6));
      // Native plain Tab is delivered through its ordered channel action.
      final client =
          (tester.testTextInput.log
                      .lastWhere((c) => c.method == 'TextInput.setClient')
                      .arguments
                  as List)
              .first;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.performAction', [
            client,
            'TextInputAction.next',
          ]),
        ),
        (_) {},
      );
      expect(c.state.doc.child(0).textContent, '    foo');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(c.state.doc.child(0).textContent, '    foo\n    ');
      final mod = defaultTargetPlatform == TargetPlatform.iOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(mod);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(mod);
      expect(c.state.doc.childCount, 2);
      expect(
        c.state.doc.resolve(c.state.selection.head).parent.type,
        'paragraph',
      );
      await _unmount(tester);
    },
    variant: _mobile,
  );

  testWidgets(
    'cell atom arrows stay in its container; Escape collapses node and rectangular selection',
    (tester) async {
      final c = _doc([
        _schema.node(
          'table',
          content: [
            _schema.node(
              'tableRow',
              content: [
                _schema.node(
                  'tableCell',
                  content: [
                    _schema.node('image', attrs: {'src': 'fixture'}),
                  ],
                ),
                _schema.node('tableCell', content: [_p('other')]),
              ],
            ),
          ],
        ),
      ]);
      await _mount(tester, c);
      c.setSelection(ft.NodeSelection(c.state.doc, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(c.state.selection, const ft.GapSelection(3));
      c.setSelection(ft.NodeSelection(c.state.doc, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(c.state.selection, const ft.GapSelection(4));
      c.setSelection(ft.NodeSelection(c.state.doc, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(c.state.selection, const ft.GapSelection(4));
      c.setSelection(ft.CellSelection(c.state.doc, 2, 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(c.state.selection, isA<ft.TextSelection>());
      expect(
        ft.tableContext(c.state.doc, c.state.selection.head)!.cellPosition,
        5,
      );
      c.setSelection(ft.CellSelection(c.state.doc, 5, 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(c.state.selection, const ft.GapSelection(3));
      await _unmount(tester);
    },
    variant: _mobile,
  );
  testWidgets(
    'focused Apple checkbox hold places caret without toggling the task',
    (tester) async {
      final c = _doc([
        _schema.node(
          'taskList',
          content: [
            _schema.node(
              'taskItem',
              attrs: {'checked': false},
              content: [_p('task')],
            ),
          ],
        ),
      ]);
      final state = await _mount(tester, c);
      final rect = state.geometry!.taskCheckboxRect(3)!;
      await tester.longPressAt(rect.center);
      expect(c.state.doc.child(0).child(0).attrs['checked'], false);
      expect(c.state.selection.empty, true);
      await _unmount(tester);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
