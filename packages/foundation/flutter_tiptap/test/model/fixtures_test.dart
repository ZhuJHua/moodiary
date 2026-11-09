import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';
import 'package:moodiary_lint/testing.dart';

void main() {
  final file = File(
    '$repoRoot/packages/foundation/flutter_tiptap/test/fixtures/scenarios.json',
  );
  final scenarios = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final schema = Schema.standard();
  const commands = EditorCommands(trailingParagraph: true);
  for (final scenario in scenarios) {
    test(scenario['name'] as String, () {
      final sel = scenario['selection'] as Map;
      var state = EditorState(
        doc: schema.fromJson(scenario['doc'] as Map<String, dynamic>),
        selection: TextSelection(sel['anchor'] as int, sel['head'] as int),
      );
      var search = SearchIndex();
      for (final raw in scenario['ops'] as List) {
        final op = raw as Map;
        if (op['type'] == 'composition') {
          state = state.apply(
            commands.execute(state, 'insertText', {
              'text': op['text'],
              'committed': false,
              'composition': 1,
            }),
          );
          state = state.apply(
            commands.execute(state, 'commitComposition', {'composition': 1}),
          );
          continue;
        }
        final String name;
        final Map<String, dynamic> args;
        switch (op['type']) {
          case 'type':
            name = 'insertText';
            args = {'text': op['text']};
          case 'key':
            name = switch (op['key']) {
              'Backspace' => 'deleteBackward',
              'Delete' => 'deleteForward',
              'Enter' => 'splitBlock',
              'Shift-Enter' => 'hardBreak',
              'Mod-Enter' => 'exitCode',
              'ArrowDown' || 'Shift-ArrowDown' => 'arrowDown',
              'ArrowUp' || 'Shift-ArrowUp' => 'arrowUp',
              'ArrowLeft' || 'Shift-ArrowLeft' => 'arrowLeft',
              'ArrowRight' || 'Shift-ArrowRight' => 'arrowRight',
              'Tab' => 'tab',
              'Shift-Tab' => 'shiftTab',
              _ => throw StateError('Unknown key'),
            };
            args = {'extend': (op['key'] as String).startsWith('Shift-Arrow')};
          default:
            name = op['name'] as String;
            args = (op['args'] as Map?)?.cast<String, dynamic>() ?? {};
        }
        if (name == 'pasteSlice' && args['slice'] is Map) {
          final raw = args['slice'] as Map;
          args['slice'] = Slice(
            Fragment(
              (raw['content'] as List).map(
                (n) => schema.fromJson((n as Map).cast<String, dynamic>()),
              ),
            ),
            raw['openStart'] as int,
            raw['openEnd'] as int,
          );
        }
        if (name == 'startSearch') {
          search = SearchIndex(
            query: args['query'] as String,
            caseSensitive: args['caseSensitive'] == true,
          );
          state = state.apply(search.start(state));
        } else if (name == 'findNext' || name == 'findPrev') {
          state = state.apply(
            search.next(state, backwards: name == 'findPrev'),
          );
        } else if (name == 'replaceCurrent') {
          state = state.apply(
            search.replaceCurrent(state, args['text'] as String),
          );
        } else if (name == 'replaceAll') {
          state = state.apply(search.replaceAll(state, args['text'] as String));
        } else if (name == 'clearSearch') {
          search = SearchIndex();
        } else {
          state = state.apply(commands.execute(state, name, args));
        }
      }
      final expected =
          (scenario['deviation'] != null
                  ? scenario['nativeExpected']
                  : scenario['expected'])
              as Map;
      expect(state.doc.toJson(), expected['doc']);
      expect({
        'anchor': state.selection.anchor,
        'head': state.selection.head,
      }, expected['selection']);
      expect(jsonDecode(state.doc.toJsonString()), expected['doc']);
      if (expected['search'] != null) {
        final hits = search.findAll(state.doc),
            current = hits.indexWhere(
              (m) =>
                  m.from == state.selection.from && m.to == state.selection.to,
            );
        expect({
          'query': search.query,
          'total': hits.length,
          'current': current + 1,
        }, expected['search']);
      }
    });
    test('round trip ${scenario['name']}', () {
      final node = schema.fromJson(scenario['doc'] as Map<String, dynamic>);
      expect(
        schema.parse(node.toJsonString()).toJsonString(),
        node.toJsonString(),
      );
    });
  }
}
