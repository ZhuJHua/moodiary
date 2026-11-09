import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/large_doc.dart';

// The engine owns this state. Outbound framework updates can stay in flight
// while subsequent native deltas are computed, just as on the iOS input queue.
class _Ime {
  _Ime(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.setClient') {
          client = (call.arguments as List).first as int;
        } else if (call.method == 'TextInput.setEditingState') {
          final next = TextEditingValue.fromJSON(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          sent.add(next);
          if (holdUpdates) {
            pending.add(next);
            final reply = Completer<void>();
            _replies.add(reply);
            return reply.future;
          } else {
            value = next;
          }
        } else if (call.method == 'TextInput.show') {
          visible = true;
        }
        return;
      },
    );
    addTearDown(() {
      for (final reply in _replies) {
        reply.complete();
      }
      tester.testTextInput.register();
    });
  }
  final WidgetTester tester;
  int? client;
  bool holdUpdates = false, visible = false;
  TextEditingValue value = TextEditingValue.empty;
  final sent = <TextEditingValue>[], pending = <TextEditingValue>[];
  final _replies = <Completer<void>>[];
  final _queued = <Map<String, Object?>>[];
  bool get hasQueued => _queued.isNotEmpty;

  Future<void> message(String name, dynamic arguments) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(name, [client!, arguments]),
      ),
      (_) {},
    );
  }

  Future<void> edit({
    String text = '',
    int? from,
    int? to,
    TextRange composing = TextRange.empty,
    bool selectionOnly = false,
    bool queue = false,
    int? caret,
  }) async {
    final before = value;
    from ??= before.selection.start;
    to ??= before.selection.end;
    final nextText = selectionOnly
        ? before.text
        : before.text.replaceRange(from, to, text);
    caret ??= selectionOnly
        ? before.selection.extentOffset
        : from + text.length;
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret),
      composing: composing,
    );
    final packet = <String, Object?>{
      'deltas': [
        {
          'oldText': before.text,
          'deltaStart': selectionOnly ? -1 : from,
          'deltaEnd': selectionOnly ? -1 : to,
          'deltaText': text,
          'selectionBase': caret,
          'selectionExtent': caret,
          'composingBase': composing.start,
          'composingExtent': composing.end,
        },
      ],
    };
    if (queue) {
      _queued.add(packet);
    } else {
      await message('TextInputClient.updateEditingStateWithDeltas', packet);
    }
  }

  Future<void> flush() async {
    for (final packet in _queued) {
      await message('TextInputClient.updateEditingStateWithDeltas', packet);
    }
    _queued.clear();
  }

  Future<void> returnAction() =>
      message('TextInputClient.performAction', 'TextInputAction.newline');
}

// Flutter 3.47.8 InputConnectionAdaptor.handleKeyEvent, ACTION_DOWN:
// arrows adjust selection, multiline Enter inserts its Unicode character,
// DEL/FORWARD_DEL have Unicode 0 and produce no fallback edit.
class _AndroidKeyboard {
  _AndroidKeyboard(this.ime);
  final _Ime ime;
  int fallbackEdits = 0, redispatched = 0;
  Future<bool> key(
    LogicalKeyboardKey key, {
    bool enterHasCharacter = true,
  }) async {
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    final handled = await ime.tester.sendKeyEvent(
      key,
      character: enter && enterHasCharacter ? '\n' : null,
    );
    if (handled) return true;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      redispatched++;
      return false;
    }
    if ((enter && enterHasCharacter) || key == LogicalKeyboardKey.tab) {
      fallbackEdits++;
      await ime.edit(
        text: key == LogicalKeyboardKey.tab ? '\t' : '\n',
        queue: ime.hasQueued,
      );
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      fallbackEdits++;
      final caret =
          (ime.value.selection.extentOffset +
                  (key == LogicalKeyboardKey.arrowLeft ? -1 : 1))
              .clamp(0, ime.value.text.length);
      await ime.edit(selectionOnly: true, caret: caret, queue: ime.hasQueued);
    } else {
      redispatched++;
    }
    return false;
  }

  Future<void> commitText(String text) => ime.edit(text: text);
  Future<void> deleteSurroundingText(int before, int after) => ime.edit(
    from: (ime.value.selection.start - before).clamp(0, ime.value.text.length),
    to: (ime.value.selection.end + after).clamp(0, ime.value.text.length),
  );
}

void main() {
  final schema = ft.Schema.standard();
  ft.TiptapController document(String text) => ft.TiptapController(
    doc: schema.node(
      'doc',
      content: [
        schema.node(
          'paragraph',
          content: [if (text.isNotEmpty) schema.node('text', text: text)],
        ),
      ],
    ),
  );
  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    bool autofocus = true,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: ft.TiptapEditor(
          key: key,
          controller: controller,
          autofocus: autofocus,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return key;
  }

  const androidPlatform = TargetPlatformVariant({TargetPlatform.android});
  for (final key in [LogicalKeyboardKey.backspace, LogicalKeyboardKey.delete]) {
    testWidgets(
      'Android $key is handled once; engine has no deletion fallback',
      (tester) async {
        final ime = _Ime(tester), c = document('');
        final keyboard = _AndroidKeyboard(ime);
        await mount(tester, c);
        await keyboard.commitText('abcd');
        if (key == LogicalKeyboardKey.delete) {
          await ime.edit(selectionOnly: true, caret: 4);
        }
        final sent = ime.sent.length;
        expect(await keyboard.key(key), isTrue);
        expect(c.state.doc.blocks.first.textContent, 'abc');
        expect(ime.value.text, '\u200babc');
        expect(
          ime.sent.length,
          sent + 1,
          reason: 'framework edit must update the actual native buffer',
        );
        expect(keyboard.fallbackEdits, 0);
        expect(keyboard.redispatched, 0);
        await keyboard.commitText('X');
        expect(c.state.doc.blocks.first.textContent, 'abcX');
      },
      variant: androidPlatform,
    );
  }

  testWidgets(
    'Android KEYCODE_DEL preserves live composition and deletes graphemes',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      final keyboard = _AndroidKeyboard(ime);
      await mount(tester, c);
      await ime.edit(
        text: 'Title',
        composing: const TextRange(start: 1, end: 6),
      );
      expect(await keyboard.key(LogicalKeyboardKey.backspace), isTrue);
      expect(c.state.doc.blocks.first.textContent, 'Titl');
      expect(c.composing, const TextRange(start: 1, end: 5));
      expect(ime.value.composing, c.composing);
      await ime.edit(selectionOnly: true);
      c.exec('undo');
      expect(c.state.doc.blocks.first.textContent, '');
      await keyboard.commitText('a👨‍👩‍👧‍👦b');
      await keyboard.key(LogicalKeyboardKey.backspace);
      await keyboard.key(LogicalKeyboardKey.backspace);
      expect(c.state.doc.blocks.first.textContent, 'a');
      expect(ime.value.text, '\u200ba');
    },
    variant: androidPlatform,
  );

  for (final keyEvent in [true, false]) {
    testWidgets(
      'Android ${keyEvent ? 'KEYCODE_DEL' : 'deleteSurroundingText'} deletes the empty-paragraph sentinel and joins',
      (tester) async {
        final ime = _Ime(tester);
        final c = ft.TiptapController(
          state: ft.EditorState(
            doc: schema.node(
              'doc',
              content: [
                schema.node(
                  'paragraph',
                  content: [schema.node('text', text: 'ab')],
                ),
                schema.node('paragraph'),
              ],
            ),
            selection: const ft.TextSelection(5),
          ),
        );
        final keyboard = _AndroidKeyboard(ime);
        await mount(tester, c);
        expect(ime.value.text, '\u200b');
        if (keyEvent) {
          expect(await keyboard.key(LogicalKeyboardKey.backspace), isTrue);
        } else {
          await keyboard.deleteSurroundingText(1, 0);
        }
        expect(c.state.doc.childCount, 1);
        expect(c.state.doc.blocks.first.textContent, 'ab');
        expect(c.state.selection.head, 3);
        expect(ime.value.text, '\u200bab');
        await keyboard.commitText('c');
        expect(c.state.doc.blocks.first.textContent, 'abc');
      },
      variant: androidPlatform,
    );
  }

  testWidgets(
    'Android direct commitText and deleteSurroundingText edits are not echoed or duplicated',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      final keyboard = _AndroidKeyboard(ime);
      await mount(tester, c);
      final sent = ime.sent.length;
      await keyboard.commitText('abcd');
      await keyboard.deleteSurroundingText(1, 0);
      expect(c.state.doc.blocks.first.textContent, 'abc');
      expect(ime.sent.length, sent);
      await ime.edit(selectionOnly: true, caret: 3);
      await keyboard.deleteSurroundingText(0, 1);
      expect(c.state.doc.blocks.first.textContent, 'ab');
      expect(ime.value.text, '\u200bab');
      expect(ime.sent.length, sent);
    },
    variant: androidPlatform,
  );

  testWidgets(
    'Android KEYCODE_DEL can undo an input rule and keeps native Enter and document-owned arrows',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      final keyboard = _AndroidKeyboard(ime);
      await mount(tester, c);
      await keyboard.commitText('## ');
      expect(c.state.doc.blocks.first.type, 'heading');
      expect(await keyboard.key(LogicalKeyboardKey.backspace), isTrue);
      expect(c.state.doc.blocks.first.type, 'paragraph');
      expect(c.state.doc.blocks.first.textContent, '## ');
      expect(ime.value.text, '\u200b## ');
      await keyboard.commitText('abc');
      expect(await keyboard.key(LogicalKeyboardKey.arrowLeft), isTrue);
      await keyboard.commitText('X');
      expect(c.state.doc.blocks.first.textContent, '## abXc');
      expect(await keyboard.key(LogicalKeyboardKey.enter), isFalse);
      expect(c.state.doc.blocks.map((b) => b.textContent), ['## abX', 'c']);
      expect(keyboard.fallbackEdits, 1);
      expect(keyboard.redispatched, 0);
    },
    variant: androidPlatform,
  );

  testWidgets(
    'Android deletion repeats and first-empty-block sentinel stay synchronized',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      await mount(tester, c);
      await ime.edit(text: 'ab');
      expect(
        await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace),
        isTrue,
      );
      expect(
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace),
        isTrue,
      );
      expect(await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace), isTrue);
      expect(c.state.doc.blocks.first.textContent, '');
      expect(ime.value.text, '\u200b');
      final keyboard = _AndroidKeyboard(ime);
      await keyboard.key(LogicalKeyboardKey.backspace);
      expect(c.state.doc.blocks.first.textContent, '');
      expect(ime.value.text, '\u200b');
      await keyboard.deleteSurroundingText(1, 0);
      expect(c.state.doc.blocks.first.textContent, '');
      expect(ime.value.text, '\u200b');
      await keyboard.commitText('X');
      expect(c.state.doc.blocks.first.textContent, 'X');
    },
    variant: androidPlatform,
  );

  testWidgets(
    'Android forward Delete joins at the end of the native block window',
    (tester) async {
      final ime = _Ime(tester);
      final c = ft.TiptapController(
        state: ft.EditorState(
          doc: schema.node(
            'doc',
            content: [
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'ab')],
              ),
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'cd')],
              ),
            ],
          ),
          selection: const ft.TextSelection(3),
        ),
      );
      await mount(tester, c);
      final keyboard = _AndroidKeyboard(ime);
      expect(await keyboard.key(LogicalKeyboardKey.delete), isTrue);
      expect(c.state.doc.childCount, 1);
      expect(c.state.doc.blocks.first.textContent, 'abcd');
      expect(ime.value.text, '\u200babcd');
      expect(ime.value.selection.extentOffset, 3);
      await keyboard.key(LogicalKeyboardKey.backspace);
      expect(c.state.doc.blocks.first.textContent, 'acd');
      expect(keyboard.fallbackEdits, 0);
    },
    variant: androidPlatform,
  );

  testWidgets('Android deletion keys map a windowed caret back to the document', (
    tester,
  ) async {
    final ime = _Ime(tester),
        c = document(
          '${List.filled(2499, 'a').join()}XYZ${List.filled(2498, 'b').join()}',
        );
    c.setSelection(const ft.TextSelection(2501));
    await mount(tester, c);
    final keyboard = _AndroidKeyboard(ime);
    await keyboard.key(LogicalKeyboardKey.backspace);
    await keyboard.key(LogicalKeyboardKey.delete);
    expect(c.state.doc.blocks.first.textContent.length, 4998);
    expect(c.state.doc.blocks.first.textContent.substring(2497, 2502), 'aaZbb');
    expect(c.state.selection.head, 2500);
    expect(ime.value.text.length, lessThanOrEqualTo(2049));
    await keyboard.commitText('Q');
    expect(
      c.state.doc.blocks.first.textContent.substring(2497, 2503),
      'aaQZbb',
    );
  }, variant: androidPlatform);

  testWidgets(
    'Android soft Enter with Unicode zero is handled once after earlier text deltas',
    (tester) async {
      final ime = _Ime(tester);
      final c = ft.TiptapController(commands: const ft.EditorCommands());
      await mount(tester, c);
      final keyboard = _AndroidKeyboard(ime);
      await keyboard.commitText('## ');
      await keyboard.commitText('Hea');
      final text = keyboard.commitText('ding');
      expect(c.state.doc.blocks.first.textContent, 'Heading');
      final key = keyboard.key(
        LogicalKeyboardKey.enter,
        enterHasCharacter: false,
      );
      await text;
      expect(await key, isTrue);
      expect(c.state.doc.blocks.map((b) => (b.type, b.textContent)), [
        ('heading', 'Heading'),
        ('paragraph', ''),
      ]);
      expect(ime.value.text, '\u200b');
      expect(keyboard.fallbackEdits, 0);
      expect(keyboard.redispatched, 0);
      await keyboard.commitText('next');
      expect(c.state.doc.blocks[1].textContent, 'next');
    },
    variant: androidPlatform,
  );

  testWidgets('Android IME_ACTION_NONE requests a newline without a delta', (
    tester,
  ) async {
    final ime = _Ime(tester), c = document('');
    final keyboard = _AndroidKeyboard(ime);
    await mount(tester, c);
    await keyboard.commitText('ab');
    await ime.returnAction();
    expect(c.state.doc.blocks.map((b) => b.textContent), ['ab', '']);
    expect(ime.value.text, '\u200b');
    await keyboard.commitText('cd');
    await keyboard.commitText('\n');
    expect(c.state.doc.blocks.map((b) => b.textContent), ['ab', 'cd', '']);
  }, variant: androidPlatform);

  bool mobileInput() =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  const platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  });

  ft.TiptapController headingController() => ft.TiptapController(
    doc: schema.node('doc', content: [schema.node('paragraph')]),
    // Isolate input ordering from the host's optional trailing-node plugin.
    commands: const ft.EditorCommands(),
  );
  void expectHeading(ft.TiptapController c) {
    expect(c.state.doc.toJson(), {
      'type': 'doc',
      'attrs': {'v': 2},
      'content': [
        {
          'type': 'heading',
          'attrs': {'level': 2},
          'content': [
            {'type': 'text', 'text': 'Heading'},
          ],
        },
        {'type': 'paragraph'},
      ],
    });
    expect(c.state.selection.head, 10);
  }

  testWidgets('a delta applies synchronously before a same-frame Return key', (
    tester,
  ) async {
    final ime = _Ime(tester), c = headingController();
    await mount(tester, c);
    await ime.edit(text: '## ');
    await ime.edit(text: 'Hea');
    // No frame, microtask flush, or response await between delivery and key.
    final text = ime.edit(text: 'ding');
    expect(c.state.doc.blocks.first.textContent, 'Heading');
    final key = tester.sendKeyEvent(
      LogicalKeyboardKey.enter,
      character: defaultTargetPlatform == TargetPlatform.android ? '\n' : null,
    );
    await text;
    expect(await key, !mobileInput());
    if (mobileInput()) {
      expect(c.state.doc.childCount, 1);
      await ime.edit(text: '\n');
    }
    expectHeading(c);
    // Apple engines notify the action alongside the newline insertion.
    if (defaultTargetPlatform != TargetPlatform.android) {
      await ime.returnAction();
    }
    expectHeading(c);
  }, variant: platforms);

  testWidgets(
    'mobile Return cannot overtake text still queued by the native IME',
    (tester) async {
      final ime = _Ime(tester), c = headingController();
      await mount(tester, c);
      await ime.edit(text: '## ');
      await ime.edit(text: 'Hea');
      await ime.edit(text: 'ding', queue: true);
      final key = tester.sendKeyEvent(
        LogicalKeyboardKey.enter,
        character: defaultTargetPlatform == TargetPlatform.android
            ? '\n'
            : null,
      );
      final text = ime.flush();
      expect(await key, isFalse);
      await text;
      expect(c.state.doc.childCount, 1);
      expect(c.state.doc.blocks.first.textContent, 'Heading');
      await ime.edit(text: '\n');
      if (defaultTargetPlatform != TargetPlatform.android) {
        await ime.returnAction();
      }
      expectHeading(c);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final operation in ['backspace', 'delete', 'left']) {
    testWidgets(
      'same-frame text precedes $operation through the platform owner',
      (tester) async {
        final ime = _Ime(tester),
            c = document(operation == 'delete' ? ' tail' : '');
        await mount(tester, c);
        await ime.edit(text: 'abc');
        final android = defaultTargetPlatform == TargetPlatform.android;
        final androidDelete = android && operation != 'left';
        final queued = mobileInput() && !androidDelete && operation != 'left';
        final text = ime.edit(text: 'd', queue: queued);
        expect(
          c.state.doc.blocks.first.textContent,
          startsWith(queued ? 'abc' : 'abcd'),
        );
        final logical = switch (operation) {
          'backspace' => LogicalKeyboardKey.backspace,
          'delete' => LogicalKeyboardKey.delete,
          _ => LogicalKeyboardKey.arrowLeft,
        };
        final key = android
            ? _AndroidKeyboard(ime).key(logical)
            : tester.sendKeyEvent(logical);
        await text;
        expect(
          await key,
          operation == 'left' || androidDelete || !mobileInput(),
        );
        if (mobileInput()) {
          await ime.flush();
          if (!android && operation != 'left') {
            final caret = ime.value.selection.extentOffset;
            if (operation == 'left') {
              await ime.edit(selectionOnly: true, caret: caret - 1);
            } else {
              await ime.edit(
                from: operation == 'backspace' ? caret - 1 : caret,
                to: operation == 'backspace' ? caret : caret + 1,
              );
            }
          }
        }
        await ime.edit(text: 'X');
        expect(c.state.doc.blocks.first.textContent, switch (operation) {
          'backspace' => 'abcX',
          'delete' => 'abcdXtail',
          _ => 'abcXd',
        });
      },
      variant: platforms,
    );
  }

  testWidgets(
    'mobile document navigation owns keys outside composition',
    (tester) async {
      final c = document('abc');
      final ime = _Ime(tester);
      await mount(tester, c);
      c.setSelection(const ft.TextSelection(2));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight), true);
      expect(c.state.selection, const ft.TextSelection(3));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), true);
      expect(c.state.selection, const ft.TextSelection(2));
      await ime.edit(text: 'X');
      expect(c.state.doc.blocks.first.textContent, 'aXbc');
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('Tab focus traversal stays behind earlier text input', (
    tester,
  ) async {
    final ime = _Ime(tester), c = document('');
    final target = FocusNode();
    addTearDown(c.dispose);
    addTearDown(target.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: [
            Expanded(child: ft.TiptapEditor(controller: c, autofocus: true)),
            Focus(focusNode: target, child: const SizedBox(height: 30)),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await ime.edit(text: 'Hea');
    final text = ime.edit(text: 'ding', queue: mobileInput());
    expect(
      c.state.doc.blocks.first.textContent,
      mobileInput() ? 'Hea' : 'Heading',
    );
    final key = tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await text;
    expect(await key, !mobileInput());
    if (mobileInput()) {
      expect(target.hasFocus, isFalse);
      await ime.flush();
      await ime.message(
        'TextInputClient.performAction',
        'TextInputAction.next',
      );
    }
    await tester.pump();
    expect(target.hasFocus, isTrue);
    expect(c.state.doc.blocks.first.textContent, 'Heading');
  }, variant: platforms);

  testWidgets(
    'rapid native deltas are not echoed and survive a pending input rule update',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      await mount(tester, c);
      ime.sent.clear();
      ime.holdUpdates = true;
      await ime.edit(text: '#');
      await ime.edit(text: '#');
      expect(
        ime.sent,
        isEmpty,
        reason: 'ordinary typing must not reset the native input session',
      );
      await ime.edit(text: ' ');
      expect(c.state.doc.blocks.first.type, 'heading');
      expect(c.state.doc.blocks.first.attrs['level'], 2);
      expect(ime.pending, hasLength(1));
      expect(ime.value.text, '\u200b## ');
      await ime.edit(text: '中');
      await ime.edit(text: '文');
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, '中文');
      expect(c.state.selection.head, 3);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'stale oldText is rebased without dropping subsequent native input',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      await mount(tester, c);
      ime.holdUpdates = true;
      c.exec('insertText', {'text': 'A'});
      expect(ime.value.text, '\u200b');
      await ime.edit(text: 'B');
      await ime.edit(text: 'C');
      await tester.pump();
      expect(c.state.doc.blocks.first.textContent, 'ABC');
      expect(c.state.selection.head, 4);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'native input in a previous long-block window keeps its document position',
    (tester) async {
      final ime = _Ime(tester), c = document(List.filled(6000, 'a').join());
      c.setSelection(const ft.TextSelection(3001));
      await mount(tester, c);
      ime.holdUpdates = true;
      for (final character in ['X', 'Y', 'Z']) {
        await ime.edit(text: character);
      }
      await tester.pump();
      final text = c.state.doc.blocks.first.textContent;
      expect(text.substring(2998, 3005), 'aaXYZaa');
      expect(c.state.selection.head, 3004);
      expect(ime.pending, isNotEmpty);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('iOS newline delta replacing marked text commits it as-is', (
    tester,
  ) async {
    final ime = _Ime(tester), c = document('');
    await mount(tester, c);
    ime.holdUpdates = true;
    await ime.edit(text: 'Title', composing: const TextRange(start: 1, end: 6));
    await ime.edit(from: 1, to: 6, text: '\n');
    await tester.pump();
    expect(c.state.doc.childCount, 1);
    expect(c.state.doc.blocks.first.textContent, 'Title');
    expect(c.composing, TextRange.empty);
    expect(ime.pending.last.text, '\u200bTitle');
    await ime.edit(selectionOnly: true);
    await ime.edit(text: '\n');
    await ime.returnAction();
    expect(c.state.doc.childCount, 2);
    expect(c.state.doc.blocks.first.textContent, 'Title');
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  for (final hardware in [false, true]) {
    testWidgets(
      '${hardware ? 'hardware' : 'IME action'} Return commits Pinyin marked text without splitting',
      (tester) async {
        final ime = _Ime(tester), c = document('');
        await mount(tester, c);
        ime.holdUpdates = true;
        await ime.edit(
          text: 'Title',
          composing: const TextRange(start: 1, end: 6),
        );
        expect(c.composing, const TextRange(start: 1, end: 6));
        if (hardware) {
          final revision = c.revision;
          for (final key in [
            LogicalKeyboardKey.enter,
            LogicalKeyboardKey.backspace,
            LogicalKeyboardKey.delete,
            LogicalKeyboardKey.arrowLeft,
            LogicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowUp,
            LogicalKeyboardKey.arrowDown,
          ]) {
            expect(
              await tester.sendKeyEvent(
                key,
                character:
                    defaultTargetPlatform == TargetPlatform.android &&
                        (key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter)
                    ? '\n'
                    : null,
              ),
              isFalse,
              reason: 'Marked-text keys must reach the native IME',
            );
            expect(c.revision, revision);
            expect(c.composing, const TextRange(start: 1, end: 6));
          }
          await ime.message('TextInputClient.performSelectors', [
            'insertNewline:',
            'deleteBackward:',
            'moveLeft:',
          ]);
          expect(c.revision, revision);
          expect(ime.pending, isEmpty);
        } else {
          await ime.returnAction();
        }
        // iOS subsequently acknowledges unmarkText using its own prior state.
        await ime.edit(selectionOnly: true);
        await tester.pump();
        expect(c.state.doc.childCount, 1);
        expect(c.state.doc.blocks.first.textContent, 'Title');
        expect(c.composing, TextRange.empty);
        if (hardware) {
          expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
        }
        await ime.edit(text: '\n');
        await ime.returnAction();
        await tester.pump();
        expect(c.state.doc.childCount, 2);
        expect(c.state.doc.blocks.first.textContent, 'Title');
        c.exec('undo');
        c.exec('undo');
        expect(c.state.doc.blocks.first.textContent, '');
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'IME character insertions keep identical marks in one text node',
    (tester) async {
      final ime = _Ime(tester), c = document('');
      await mount(tester, c);
      for (final word in ['Heading bold mark', ' **']) {
        for (final char in word.split('')) {
          final start = ime.value.selection.extentOffset;
          await ime.edit(
            text: char,
            composing: TextRange(start: start, end: start + 1),
          );
          await ime.edit(selectionOnly: true);
          expect(c.state.doc.blocks.first.childCount, 1);
        }
      }
      expect(c.state.doc.blocks.first.textContent, 'Heading bold mark **');
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  for (final commit in ['composition', 'punctuation']) {
    testWidgets(
      'Pinyin rules through $commit commits keep queued native edits and plain suffixes',
      (tester) async {
        final ime = _Ime(tester), c = document(' tail');
        await mount(tester, c);
        ime.holdUpdates = true;
        await ime.edit(text: 'a **');
        Future<void> word(String text, String delimiter) async {
          final start = ime.value.selection.extentOffset;
          for (final letter in text.split('')) {
            final end = ime.value.selection.extentOffset + letter.length;
            await ime.edit(
              text: letter,
              composing: TextRange(start: start, end: end),
            );
            final revision = c.revision;
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            expect(c.revision, revision);
            expect(c.state.doc.childCount, 1);
          }
          if (commit == 'composition') {
            await ime.edit(
              text: delimiter,
              composing: TextRange(
                start: start,
                end: ime.value.selection.extentOffset + delimiter.length,
              ),
            );
            await ime.edit(selectionOnly: true);
          } else {
            for (final character in delimiter.split('')) {
              await ime.edit(text: character);
            }
          }
          expect(c.lastTransaction!.metadata['inputRule'], isTrue);
          expect(c.composing, TextRange.empty);
        }

        await word('bold', '**');
        await ime.edit(text: ' b ==');
        await word('mark', '==');
        await ime.edit(text: ' c');
        await tester.pump();
        expect(c.state.doc.blocks.first.toJson(), {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'a '},
            {
              'type': 'text',
              'text': 'bold',
              'marks': [
                {'type': 'bold'},
              ],
            },
            {'type': 'text', 'text': ' b '},
            {
              'type': 'text',
              'text': 'mark',
              'marks': [
                {
                  'type': 'highlight',
                  'attrs': {'color': null},
                },
              ],
            },
            {'type': 'text', 'text': ' c tail'},
          ],
        });
        expect(c.state.selection.head, 16);
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
        await ime.edit(text: '\n');
        expect(c.state.doc.childCount, 2);
        expect(c.state.doc.blocks[1].textContent, ' tail');
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'the first touch immediately positions the caret and opens an input client',
    (tester) async {
      final ime = _Ime(tester), c = document('hello world');
      final key = await mount(tester, c, autofocus: false);
      expect(ime.client, isNull);
      final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      await tester.tapAt(
        origin + key.currentState!.geometry!.caretRect(5).center,
      );
      await tester.pump();
      expect(c.state.selection.head, 5);
      expect(ime.client, isNotNull);
      expect(ime.visible, isTrue);
      await ime.edit(text: '中');
      expect(c.state.doc.blocks.first.textContent, 'hell中o world');
      // A second tap still selects a word without delaying the first tap.
      await tester.tapAt(
        origin + key.currentState!.geometry!.caretRect(5).center,
      );
      await tester.pump();
      expect(c.state.selection.empty, isFalse);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'range handles hang their knobs above the start and below the end',
    (tester) async {
      final c = document('hello world');
      final key = await mount(tester, c);
      final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      await tester.tapAt(
        origin + key.currentState!.geometry!.caretRect(2).center,
      );
      await tester.pump();
      c.setSelection(const ft.TextSelection(1, 5));
      await tester.pump();
      await tester.pump();
      final start = find.byKey(const ValueKey('tiptap-handle-start'));
      final end = find.byKey(const ValueKey('tiptap-handle-end'));
      expect(start, findsOneWidget);
      expect(end, findsOneWidget);
      final geometry = key.currentState!.geometry!;
      expect(
        tester.getTopLeft(start) + const Offset(22, 22),
        origin + geometry.caretRect(1).topCenter - const Offset(0, 6),
      );
      expect(
        tester.getTopLeft(end) + const Offset(22, 22),
        origin + geometry.caretRect(5).bottomCenter + const Offset(0, 6),
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'caret ring sits under the caret and hides on typing or after 2 s',
    (tester) async {
      final ime = _Ime(tester), c = document('hello');
      final key = await mount(tester, c);
      final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
      final handle = find.byKey(const ValueKey('tiptap-handle-caret'));
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: handle, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      Future<void> tap(int position) async {
        await tester.tapAt(
          origin + key.currentState!.geometry!.caretRect(position).center,
        );
        await tester.pump();
        await tester.pump();
      }

      await tap(2);
      expect(opacity(), 1);
      // Let the caret finish gliding to the tap.
      await tester.pump(const Duration(milliseconds: 200));
      final caret = key.currentState!.debugCaret.rect!;
      final ring = tester.getTopLeft(handle) + const Offset(22, 8);
      expect(ring.dx, moreOrLessEquals(origin.dx + caret.center.dx));
      expect(ring.dy, moreOrLessEquals(origin.dy + caret.bottom + 8));

      await ime.edit(text: '中');
      await tester.pump();
      expect(opacity(), 0);

      await tester.pump(const Duration(milliseconds: 500));
      await tap(6);
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), 0);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('a long press keeps its word until the finger leaves it', (
    tester,
  ) async {
    final c = document('hello world again');
    final key = await mount(tester, c);
    final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
    Offset at(int position) =>
        origin + key.currentState!.geometry!.caretRect(position).center;
    (int, int) range() => (c.state.selection.from, c.state.selection.to);
    final gesture = await tester.startGesture(at(9));
    await tester.pump(const Duration(milliseconds: 600));
    expect(range(), (7, 12));
    await gesture.moveTo(at(9) + const Offset(2, 1));
    await tester.pump();
    expect(range(), (7, 12));
    await gesture.moveTo(at(16));
    await tester.pump();
    expect(range(), (7, 16));
    await gesture.up();
    await tester.pump();
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('range and caret handles win drags over the scroll view', (
    tester,
  ) async {
    final c = document(List.filled(80, 'hello world').join(' '));
    final key = await mount(tester, c);
    final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
    await tester.tapAt(
      origin + key.currentState!.geometry!.caretRect(3).center,
    );
    await tester.pump(const Duration(milliseconds: 200));
    c.setSelection(const ft.TextSelection(1, 5));
    await tester.pump();
    final end = find.byKey(const ValueKey('tiptap-handle-end'));
    final scroll = key.currentState!.geometry!.scrollOffset;
    // Mostly vertical, the direction Scrollable would otherwise claim.
    await tester.drag(end, const Offset(30, 60));
    await tester.pump();
    expect(key.currentState!.geometry!.scrollOffset, scroll);
    final selection = c.state.selection;
    expect(selection.from, 1);
    expect(selection.to, greaterThan(5));

    await tester.tapAt(
      origin + key.currentState!.geometry!.caretRect(3).center,
    );
    await tester.pump(const Duration(milliseconds: 500));
    final caret = find.byKey(const ValueKey('tiptap-handle-caret'));
    await tester.drag(caret, const Offset(80, 0));
    await tester.pump();
    expect(c.state.selection.empty, isTrue);
    expect(c.state.selection.from, greaterThan(3));
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'ZWJ emoji paragraph matches a plain Text with the same system font',
    (tester) async {
      const family = '👨‍👩‍👧‍👦';
      final ime = _Ime(tester), c = document('');
      final key = await mount(tester, c);
      await ime.edit(text: family);
      await tester.pump();
      final base = const ft.TiptapEditorStyle().forBlock(
        c.state.doc.blocks.first,
      );
      expect(base.fontFamily, '.AppleSystemUIFont');
      expect(base.fontFamilyFallback, contains('Apple Color Emoji'));
      expect(c.state.doc.blocks.first.textContent, family);
      final rect = key.currentState!.geometry!
          .selectionRects(1, family.length + 1)
          .single;
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await tester.pump();
      final editorBoundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .descendant(
              of: find.byType(ft.TiptapEditor),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      final size = editorBoundary.size;
      Future<List<int>> pixels(RenderRepaintBoundary boundary) async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!.buffer.asUint8List();
      }

      final editorPixels = await tester.runAsync(() => pixels(editorBoundary));
      key.currentState!.requestKeyboard();
      await tester.pump();
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.backspace), isFalse);
      await ime.edit(from: 1, to: ime.value.selection.extentOffset);
      expect(c.state.doc.blocks.first.textContent, '');
      final textKey = GlobalKey();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: RepaintBoundary(
              key: textKey,
              child: SizedBox.fromSize(
                size: size,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(family, style: base.copyWith(inherit: false)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final reference = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      final referenceBox = reference
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: family.length),
            boxHeightStyle: ui.BoxHeightStyle.strut,
          )
          .single;
      expect(rect.width, referenceBox.right - referenceBox.left);
      expect(rect.height, referenceBox.bottom - referenceBox.top);
      final referencePixels = await tester.runAsync(
        () => pixels(
          tester.renderObject<RenderRepaintBoundary>(find.byKey(textKey)),
        ),
      );
      expect(editorPixels, referencePixels);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    '1M document engine-owned typing never echoes or scans other blocks',
    (tester) async {
      final ime = _Ime(tester);
      final c = ft.TiptapController(doc: generateLargeDocument(1000000));
      await mount(tester, c);
      ime.sent.clear();
      ime.holdUpdates = true;
      final scans = c.diagnostics.fullDocumentScans;
      for (var i = 0; i < 100; i++) {
        final layouts = c.diagnostics.blockLayouts;
        await ime.edit(text: 'x');
        await tester.pump();
        await tester.pump();
        expect(c.diagnostics.blockLayouts - layouts, 1);
        expect(c.diagnostics.fullDocumentScans, scans);
      }
      expect(ime.sent, isEmpty);
      expect(c.state.doc.blocks.summary.textLength, 1000100);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
