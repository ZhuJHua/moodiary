import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' show TiptapEditorState;

class FakeIme {
  FakeIme(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call);
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
          } else if (hold) {
            pending.add(next);
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
  final calls = <MethodCall>[];
  int? client;
  bool holdUpdates = false, hold = false, visible = false;
  TextEditingValue value = TextEditingValue.empty;
  final sent = <TextEditingValue>[], pending = <TextEditingValue>[];
  final _replies = <Completer<void>>[];
  final _queued = <Map<String, Object?>>[];
  bool get hasQueued => _queued.isNotEmpty;

  static Future<void> _message(
    WidgetTester tester,
    int client,
    String name,
    Object? arguments,
  ) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(name, [client, arguments]),
      ),
      (_) {},
    );
  }

  Future<void> message(String name, Object? arguments) =>
      _message(tester, client!, name, arguments);

  static Future<void> delta(
    WidgetTester tester,
    GlobalKey<TiptapEditorState> key, {
    String text = '',
    int? from,
    int? to,
    TextRange composing = TextRange.empty,
    int? caret,
  }) async {
    final before = key.currentState!.debugInputValue;
    from ??= before.selection.start;
    to ??= before.selection.end;
    final client =
        (tester.testTextInput.log
                        .lastWhere(
                          (call) => call.method == 'TextInput.setClient',
                        )
                        .arguments
                    as List)
                .first
            as int;
    await _message(
      tester,
      client,
      'TextInputClient.updateEditingStateWithDeltas',
      _deltaPacket(
        before,
        from,
        to,
        text,
        caret ?? from + text.length,
        composing,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  static Map<String, Object?> _deltaPacket(
    TextEditingValue before,
    int from,
    int to,
    String text,
    int caret,
    TextRange composing, {
    bool selectionOnly = false,
  }) => {
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
    final packet = _deltaPacket(
      before,
      from,
      to,
      text,
      caret,
      composing,
      selectionOnly: selectionOnly,
    );
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
