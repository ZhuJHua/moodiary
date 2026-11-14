import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';
import 'package:moodiary_lint/testing.dart';

import '../support/large_doc.dart';
import '../support/nodes.dart';

void main() {
  final schema = Schema.standard();
  const commands = EditorCommands();
  final p = TestNodes(schema).p;
  final doc = TestNodes(schema).doc;
  EditorState exec(
    EditorState s,
    String name, [
    Map<String, dynamic> args = const {},
  ]) => s.apply(commands.execute(s, name, args));

  test(
    'toolbar equality compares formatting sets without depending on order',
    () {
      const first = ToolbarState(
        {'bold', 'italic'},
        'paragraph',
        null,
        true,
        false,
        SelectionKind.text,
        activeNodes: {'bulletList', 'listItem'},
        cellPosition: 7,
      );
      const reordered = ToolbarState(
        {'italic', 'bold'},
        'paragraph',
        null,
        true,
        false,
        SelectionKind.text,
        activeNodes: {'listItem', 'bulletList'},
        cellPosition: 7,
      );
      const otherCell = ToolbarState(
        {'bold', 'italic'},
        'paragraph',
        null,
        true,
        false,
        SelectionKind.text,
        activeNodes: {'bulletList', 'listItem'},
        cellPosition: 12,
      );
      const checkedTask = ToolbarState(
        {'bold', 'italic'},
        'paragraph',
        null,
        true,
        false,
        SelectionKind.text,
        activeNodes: {'bulletList', 'listItem'},
        cellPosition: 7,
        taskChecked: true,
      );
      expect(first, reordered);
      expect(first.hashCode, reordered.hashCode);
      expect(first, isNot(otherCell));
      expect(first, isNot(checkedTask));
    },
  );

  test('persistent tree randomized replacements retain summaries, order and old roots', () {
    final random = Random(42);
    var list = List.generate(
      1000,
      (i) => i % 13 == 0
          ? schema.node('heading', content: [schema.node('text', text: '$i')])
          : p('$i'),
    );
    var tree = BlockTree(list);
    for (var round = 0; round < 1500; round++) {
      final old = tree, oldList = List<Node>.of(list);
      final from = random.nextInt(list.length + 1);
      final to = min(list.length, from + random.nextInt(12));
      final added = List.generate(random.nextInt(12), (i) => p('$round:$i'));
      tree = tree.replace(from, to, added);
      list = [...list.take(from), ...added, ...list.skip(to)];
      expect(tree.toList(), list);
      expect(old.toList(), oldList);
      expect(
        tree.height,
        lessThanOrEqualTo(2 * (log(list.length + 1) / ln2).ceil() + 1),
      );
      expect(
        tree.summary.textLength,
        list.fold<int>(0, (s, n) => s + n.textLength),
      );
      expect(
        tree.summary.headingCount,
        list.where((n) => n.type == 'heading').length,
      );
      var position = 0;
      for (var i = 0; i < tree.length; i++) {
        expect(tree.positionAt(i), position);
        expect(tree.indexAt(position), i);
        expect(tree.indexAt(position + list[i].nodeSize - 1), i);
        position += list[i].nodeSize;
      }
      expect(tree.positionAt(tree.length), position);
      expect(tree.indexAt(position), tree.length);
    }
  });

  test('ProseMirror UTF-16 positions and resolved paths', () {
    final d = doc([p('a😀'), p('中')]);
    expect(d.nodeSize, 10);
    final r = d.resolve(3);
    expect(r.depth, 1);
    expect(r.start(), 1);
    expect(r.end(), 4);
    expect(r.before(), 0);
    expect(r.after(), 5);
    expect(r.parentOffset, 2);
    expect(r.textOffset, 2);
    expect(r.index(0), 0);
    expect(d.resolve(5).depth, 0);
    expect(d.resolve(6).blockIndex, 1);
    expect(() => d.resolve(9), throwsRangeError);
  });

  test('step maps obey associations, deletion flags and inverses', () {
    const map = StepMap(3, 2, 4);
    expect(map.map(3), 3);
    expect(map.map(5), 7);
    expect(map.map(4, -1), 3);
    expect(map.map(4, 1), 7);
    expect(map.mapResult(4).deleted, isTrue);
    expect(map.mapResult(3, -1).deleted, isFalse);
    expect(map.invert().map(map.map(9)), 9);
    expect(const StepMap(3, 0, 2).map(3, -1), 3);
    expect(const StepMap(3, 0, 2).map(3), 5);
  });

  test(
    'steps invert exactly including partial marks and absent attributes',
    () {
      final d = doc([p('abc'), p('def')]);
      final steps = <Step>[
        ReplaceStep(
          2,
          3,
          Slice(Fragment([schema.node('text', text: '中文')]), 0, 0),
        ),
        AddMarkStep(2, 8, schema.mark('highlight')),
        RemoveMarkStep(1, 4, schema.mark('bold')),
        const AttrStep(0, 'future', {
          'nested': [1, 2],
        }),
        const AttrStep(-1, 'future', true),
      ];
      for (final step in steps) {
        expect(
          step.invert(d).apply(step.apply(d).doc).doc.toJson(),
          d.toJson(),
        );
      }
      final marked = AddMarkStep(2, 3, schema.mark('bold')).apply(d).doc;
      final step = AddMarkStep(1, 4, schema.mark('bold'));
      expect(
        step.invert(marked).apply(step.apply(marked).doc).doc.toJson(),
        marked.toJson(),
      );
    },
  );

  test('a fence alone on its line becomes a code block on Enter', () {
    for (final (fence, language) in [
      ('```', null),
      ('```dart', 'dart'),
      ('···', null),
    ]) {
      final d = doc([p(fence)]);
      final state = EditorState(
        doc: d,
        selection: TextSelection(1 + fence.length),
      );
      final next = commands.execute(state, 'splitBlock').doc;
      expect(next.blocks.single.type, 'codeBlock');
      expect(next.blocks.single.attrs['language'], language);
      expect(next.blocks.single.textContent, '');
    }
    final mid = EditorState(
      doc: doc([p('```x')]),
      selection: const TextSelection(3),
    );
    expect(commands.execute(mid, 'splitBlock').doc.blocks.length, 2);
  });

  test(
    'transactions expose exact edited block ranges and share untouched nodes',
    () {
      final d = doc([p('a'), p('b'), p('c')]);
      final state = EditorState(doc: d, selection: const TextSelection(5));
      final tr = commands.execute(state, 'insertText', {'text': 'x'});
      expect(
        [
          tr.replacedBlocks!.from,
          tr.replacedBlocks!.oldTo,
          tr.replacedBlocks!.newTo,
        ],
        [1, 2, 2],
      );
      expect(tr.doc.blocks[0], same(d.blocks[0]));
      expect(tr.doc.blocks[2], same(d.blocks[2]));
      expect(d.blocks[1].textContent, 'b');
      final split = commands.execute(state, 'splitBlock');
      expect(
        [
          split.replacedBlocks!.from,
          split.replacedBlocks!.oldTo,
          split.replacedBlocks!.newTo,
        ],
        [1, 2, 3],
      );
      expect(
        () => EditorState(doc: doc([p('other')])).apply(tr),
        throwsStateError,
      );
    },
  );

  test(
    'history delay, adjacency, depth, selection and composition grouping',
    () {
      var s = EditorState(
        doc: doc([p('abc')]),
        selection: const TextSelection(2),
        history: History(depth: 2),
      );
      s = s.apply(commands.execute(s, 'insertText', {'text': 'x'}), time: 0);
      s = s.apply(commands.execute(s, 'insertText', {'text': 'y'}), time: 499);
      s = exec(s, 'undo');
      expect(s.doc.blocks[0].textContent, 'abc');
      expect(s.selection, const TextSelection(2));
      s = exec(s, 'redo');
      expect(s.doc.blocks[0].textContent, 'axybc');
      s = s.apply(commands.execute(s, 'insertText', {'text': 'z'}), time: 1500);
      s = s.apply(commands.execute(s, 'insertText', {'text': '!'}), time: 2500);
      s = exec(exec(s, 'undo'), 'undo');
      expect(s.history.canUndo, isFalse);
      var composing = EditorState(doc: doc([p('')]));
      composing = composing.apply(
        commands.execute(composing, 'insertText', {
          'text': '#',
          'committed': false,
          'composition': 1,
        }),
        time: 0,
      );
      composing = composing.apply(
        commands.execute(composing, 'insertText', {
          'text': ' ',
          'committed': false,
          'composition': 1,
        }),
        time: 10000,
      );
      expect(composing.doc.blocks[0].type, 'paragraph');
      expect(exec(composing, 'undo').doc.blocks[0].textContent, '');
    },
  );

  test('leading heading Backspace is unchanged and non-atom opaque blocks are selected', () {
    final heading = schema.node(
      'heading',
      attrs: {'level': 2},
      content: [schema.node('text', text: '标题')],
    );
    var state = EditorState(
      doc: doc([heading]),
      selection: const TextSelection(1),
    );
    state = exec(state, 'deleteBackward');
    expect(state.doc.blocks[0].type, 'heading');
    final opaque = schema.fromJson({
      'type': 'future',
      'attrs': {
        'data': [1, 2],
      },
    });
    state = EditorState(
      doc: doc([p('a'), opaque, p('b')]),
      selection: const TextSelection(5),
    );
    state = exec(state, 'deleteBackward');
    expect(state.selection, isA<NodeSelection>());
    expect(state.doc.blocks[1], same(opaque));
    state = exec(state, 'deleteBackward');
    expect(state.doc.childCount, 2);
    expect(state.selection, const TextSelection(4));
  });

  test('unknown attrs and marks are deeply immutable and survive edits', () {
    final raw = {
      'type': 'doc',
      'attrs': {
        'v': 2,
        'future': [1],
      },
      'content': [
        {
          'type': 'paragraph',
          'attrs': {
            'future': {
              'x': [2],
            },
          },
          'content': [
            {
              'type': 'text',
              'text': 'abc',
              'attrs': {'future': true},
              'marks': [
                {
                  'type': 'comment',
                  'attrs': <String, dynamic>{},
                  'future': [3],
                },
                {
                  'type': 'highlight',
                  'attrs': {
                    'color': null,
                    'future': [4],
                  },
                },
              ],
            },
          ],
        },
      ],
    };
    final d = schema.fromJson(raw);
    expect(d.toJson(), raw);
    expect(() => (d.attrs['future'] as List).add(2), throwsUnsupportedError);
    final state = exec(
      EditorState(doc: d, selection: const TextSelection(2)),
      'insertText',
      {'text': '中'},
    );
    expect(state.doc.blocks[0].attrs, d.blocks[0].attrs);
    expect(
      state.doc.blocks[0].content.first.marks.map((m) => m.toJson()).toList(),
      (raw['content'] as List).first['content'].first['marks'],
    );
  });

  test('opaque corpus round trips structurally', () {
    final corpus = jsonDecode(
      File(
        '$repoRoot/packages/foundation/flutter_tiptap/test/fixtures/documents.json',
      ).readAsStringSync(),
    ) as List;
    for (final (index, fixture) in corpus.indexed) {
      final input = fixture['doc'] as Map<String, dynamic>;
      final d = schema.fromJson(input);
      Map<String, dynamic> canonical(Map<String, dynamic> node) {
        if (!schema.nodes.containsKey(node['type'])) return node;
        final attrs = {...?node['attrs'] as Map<String, dynamic>?};
        if (node['type'] == 'image') {
          final alt = attrs.remove('alt'), title = attrs.remove('title');
          attrs.remove('width');
          attrs.remove('height');
          attrs['name'] ??= alt is String && alt.isNotEmpty
              ? alt
              : title is String && title.isNotEmpty
              ? title
              : null;
          if (attrs.containsKey('widthPercent')) {
            attrs['widthPercent'] = clampWidthPercent(attrs['widthPercent']);
          }
        }
        if (node['type'] == 'video' || node['type'] == 'audio') {
          final filename = attrs.remove('filename');
          if (filename is String) attrs['src'] ??= filename;
        }
        if (node['type'] == 'diaryLink') attrs.remove('mentionSuggestionChar');
        return {
          ...node,
          if (schema.nodes[node['type']]!.attrs.isNotEmpty ||
              node['attrs'] != null)
            'attrs': {...schema.nodes[node['type']]!.attrs, ...attrs},
          if (node['content'] != null)
            'content': (node['content'] as List)
                .map((n) => canonical(n as Map<String, dynamic>))
                .toList(),
        };
      }

      expect(d.toJson(), canonical(input), reason: 'document $index');
      expect(schema.parse(d.toJsonString()).toJson(), d.toJson());
    }
  });

  test(
    'async parse and incremental encoding only encode the changed block',
    () async {
      final d = doc([p('a'), p('b'), p('c')]);
      expect((await schema.parseAsync(d.toJsonString())).toJson(), d.toJson());
      final codec = DocumentCodec();
      codec.encode(d);
      expect(codec.encodedBlocks, 3);
      final state = exec(
        EditorState(doc: d, selection: const TextSelection(5)),
        'insertText',
        {'text': 'x'},
      );
      expect(jsonDecode(codec.encode(state.doc)), state.doc.toJson());
      expect(codec.encodedBlocks, 1);
      codec.encode(state.doc);
      expect(codec.encodedBlocks, 0);
    },
  );

  test('toolbar queries are local and stored marks take precedence', () {
    var s = EditorState(doc: doc([p('abc')]));
    s = exec(s, 'toggleMark', {'type': 'bold'});
    expect(s.toolbar.activeMarks, {'bold'});
    expect(s.toolbar.blockType, 'paragraph');
    expect(s.toolbar.selectionKind, SelectionKind.text);
    s = exec(s, 'insertText', {'text': '中'});
    expect(s.toolbar.canUndo, isTrue);
    s = exec(s, 'selectAll');
    expect(s.toolbar.selectionKind, SelectionKind.all);
  });

  test('large generator has exact budget, mixed text, long paragraph and unknown blocks', () {
    final d = generateLargeDocument(1000000);
    expect(d.blocks.summary.textLength, 1000000);
    expect(d.blocks.any((n) => n.textLength == 50000), isTrue);
    expect(d.blocks.any((n) => n.isOpaque), isTrue);
    expect(d.toJsonString(), generateLargeDocument(1000000).toJsonString());
  });
  test('selection toolbar coverage, mixed blocks and subtree ranges', () {
    final bold = schema.mark('bold');
    final d = doc([
      schema.node(
        'paragraph',
        attrs: {'level': 'future'},
        content: [
          schema.node('text', text: 'ab', marks: [bold]),
          schema.node('text', text: 'cd'),
        ],
      ),
      schema.node(
        'heading',
        attrs: {'level': 2},
        content: [
          schema.node('text', text: 'ef', marks: [bold]),
        ],
      ),
    ]);
    expect(
      EditorState(
        doc: d,
        selection: const TextSelection(1, 3),
      ).toolbar.activeMarks,
      {'bold'},
    );
    expect(
      EditorState(
        doc: d,
        selection: const TextSelection(1, 5),
      ).toolbar.activeMarks,
      isEmpty,
    );
    expect(
      EditorState(doc: d, selection: AllSelection(d)).toolbar.blockType,
      isNull,
    );
    expect(EditorState(doc: d).toolbar.headingLevel, isNull);
    expect(d.blocks.summaryBetween(1, 2).headingCount, 1);
    expect(d.blocks.summaryBetween(1, 1).blockCount, 0);
    expect(d.blocks.slice(1, 2).first, same(d.blocks[1]));
  });

  test('composition rules run on commit and undo invalidates only the edited block', () {
    var s = EditorState(
      doc: doc([p('before'), p(''), p('after')]),
      selection: const TextSelection(9),
    );
    s = s.apply(
      commands.execute(s, 'insertText', {
        'text': '## ',
        'committed': false,
        'composition': 7,
      }),
      time: 0,
    );
    expect(s.doc.blocks[1].type, 'paragraph');
    s = s.apply(
      commands.execute(s, 'commitComposition', {'composition': 7}),
      time: 2000,
    );
    expect(s.doc.blocks[1].type, 'heading');
    final undo = commands.execute(s, 'undo');
    expect(
      [
        undo.replacedBlocks!.from,
        undo.replacedBlocks!.oldTo,
        undo.replacedBlocks!.newTo,
      ],
      [1, 2, 2],
    );
    s = s.apply(undo);
    expect(s.doc.blocks[1].textContent, '');
    expect(s.selection, const TextSelection(9));
  });

  test('all-selection insertion replaces content and non-atom insertion replaces the selected placeholder', () {
    final d = doc([p('abc'), p('def')]);
    var s = exec(
      EditorState(doc: d, selection: AllSelection(d)),
      'insertText',
      {'text': '中文'},
    );
    expect(s.doc.childCount, 1);
    expect(s.doc.blocks.first.textContent, '中文');
    expect(s.selection, const TextSelection(3));
    final opaqueDoc = doc([
      schema.fromJson({'type': 'future'}),
      p(''),
    ]);
    s = exec(
      EditorState(doc: opaqueDoc, selection: NodeSelection(opaqueDoc, 0)),
      'insertText',
      {'text': 'x'},
    );
    expect(s.doc.blocks.first.type, 'paragraph');
    expect(s.selection, const TextSelection(2));
  });
  test(
    'non-history edits survive undo and redo, including edits before the event',
    () {
      for (final before in [false, true]) {
        var s = EditorState(
          doc: doc([p('abc'), p('def')]),
          selection: const TextSelection(2),
        );
        s = exec(s, 'insertText', {'text': 'X'});
        s = exec(s, 'setTextSelection', {'anchor': before ? 1 : 8});
        final patch = commands.execute(s, 'insertText', {'text': 'Y'})
          ..setMeta('addToHistory', false);
        s = s.apply(patch);
        s = exec(s, 'undo');
        expect(s.doc.blocks[0].textContent, before ? 'Yabc' : 'abc');
        expect(s.doc.blocks[1].textContent, before ? 'def' : 'dYef');
        s = exec(s, 'redo');
        expect(s.doc.blocks[0].textContent, before ? 'YaXbc' : 'aXbc');
        expect(s.doc.blocks[1].textContent, before ? 'def' : 'dYef');
      }
    },
  );

  test('non-history attrs, marks and formatting are rebased without resurrecting text', () {
    var s = EditorState(
      doc: doc([p('abc')]),
      selection: const TextSelection(2),
    );
    s = exec(s, 'insertText', {'text': 'X'});
    s = s.apply(
      s.tr
          .step(const AttrStep(-1, 'future', true))
          .setMeta('addToHistory', false),
    );
    s = s.apply(
      s.tr
          .step(AddMarkStep(1, 5, schema.mark('bold')))
          .setMeta('addToHistory', false),
    );
    s = s.apply(
      commands
          .execute(s, 'setHeading', {'level': 2})
          .setMeta('addToHistory', false),
    );
    s = exec(s, 'undo');
    expect(s.doc.attrs['future'], isTrue);
    expect(s.doc.blocks[0].type, 'heading');
    expect(s.doc.blocks[0].textContent, 'abc');
    expect(s.doc.blocks[0].content.first.marks, [schema.mark('bold')]);
    s = exec(s, 'redo');
    expect(s.doc.blocks[0].textContent, 'aXbc');
  });

  test('non-history changes after undo also survive redo', () {
    var s = EditorState(
      doc: doc([p('abc')]),
      selection: const TextSelection(2),
    );
    s = exec(s, 'insertText', {'text': 'X'});
    s = exec(s, 'undo');
    s = exec(s, 'setTextSelection', {'anchor': 1});
    s = s.apply(
      commands
          .execute(s, 'insertText', {'text': 'Y'})
          .setMeta('addToHistory', false),
    );
    s = exec(s, 'redo');
    expect(s.doc.blocks[0].textContent, 'YaXbc');
    s = exec(s, 'undo');
    expect(s.doc.blocks[0].textContent, 'Yabc');
  });
  test(
    'host atom registry extends the defaults without changing opaque JSON',
    () {
      final custom = Schema.standard(
        opaqueAtomTypes: {
          'horizontalRule',
          'image',
          'video',
          'audio',
          'attachment',
          'futureVideo',
        },
      );
      final raw = {
        'type': 'futureVideo',
        'attrs': {
          'src': 'v.mp4',
          'future': [1, 2],
        },
      };
      final d = custom.node(
        'doc',
        content: [
          custom.fromJson(raw),
          custom.node('paragraph', content: [custom.node('text', text: 'a')]),
        ],
      );
      final state = EditorState(doc: d, selection: const TextSelection(2));
      expect(d.blocks.first.isAtom, isTrue);
      expect(d.blocks.first.toJson(), raw);
      final tr = commands.execute(state, 'deleteBackward');
      expect(tr.doc.childCount, 1);
      expect(tr.doc.blocks.first.textContent, 'a');
      expect(tr.selection, const TextSelection(1));
    },
  );
}
