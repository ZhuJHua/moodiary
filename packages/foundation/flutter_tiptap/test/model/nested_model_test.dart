import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';

import '../support/large_doc.dart';
import '../support/nodes.dart';

void main() {
  final schema = Schema.standard();
  const commands = EditorCommands();
  final p = TestNodes(schema).p;
  final item = TestNodes(schema).textItem;
  final list = TestNodes(schema).list;
  final doc = TestNodes(schema).doc;

  test('content matching enforces required paragraphs, code marks and block groups', () {
    expect(schema.node('listItem').validContent(Fragment([p('x')])), isTrue);
    expect(
      schema
          .node('listItem')
          .validContent(
            Fragment([
              list([item('x')]),
            ]),
          ),
      isFalse,
    );
    expect(schema.node('bulletList').validContent(Fragment([p('x')])), isFalse);
    expect(
      schema
          .node('codeBlock')
          .validContent(
            Fragment([
              schema.node('text', text: 'x', marks: [schema.mark('bold')]),
            ]),
          ),
      isFalse,
    );
    expect(
      schema
          .node('codeBlock')
          .validContent(Fragment([schema.node('hardBreak')])),
      isFalse,
    );
    final listNode = list([item('a'), item('b')]);
    expect(listNode.canReplace(0, 2), isFalse);
    expect(listNode.canReplace(0, 1), isTrue);
    expect(listNode.canReplace(1, 1, Fragment([p('x')])), isFalse);
    expect(schema.createAndFill('listItem')!.toJson(), {
      'type': 'listItem',
      'content': [
        {'type': 'paragraph'},
      ],
    });
  });

  test('open nested slices replace across three wrapper levels and invert', () {
    final original = doc([
      schema.node(
        'blockquote',
        content: [
          list([item('abc'), item('def')]),
        ],
      ),
    ]);
    final first = 5, last = original.content.size - 5;
    final slice = original.slice(first, last);
    expect(slice.openStart, greaterThan(0));
    final step = ReplaceStep(first, last, slice);
    expect(step.apply(original).doc.toJson(), original.toJson());
    expect(
      step.invert(original).apply(step.apply(original).doc).doc.toJson(),
      original.toJson(),
    );
    final fitted = replaceStep(
      original,
      first,
      first,
      Slice(Fragment([schema.node('horizontalRule')]), 0, 0),
    )!;
    final next = fitted.apply(original).doc;
    void valid(Node node) {
      if (!node.isLeaf) {
        expect(node.validContent(node.content), isTrue, reason: node.type);
        node.content.forEach(valid);
      }
    }

    valid(next);
    expect(fitted.invert(original).apply(next).doc.toJson(), original.toJson());
  });

  test('replace-around preserves gap positions, selection and inverse', () {
    final original = doc([p('abc'), p('tail')]);
    final step = ReplaceAroundStep(
      0,
      5,
      0,
      5,
      Slice(Fragment([schema.node('blockquote')]), 0, 0),
      1,
    );
    final wrapped = step.apply(original).doc;
    expect(wrapped.child(0).child(0).textContent, 'abc');
    expect(step.getMap().map(3), 4);
    expect(step.getMap().invert().map(4), 3);
    expect(
      step.invert(original).apply(wrapped).doc.toJson(),
      original.toJson(),
    );
    expect(NodeSelection(wrapped, 1).to, 6);
    expect(Selection.near(wrapped, 0), const TextSelection(2));
  });

  test('nested edits identify the textblock and structural edits identify the list range', () {
    final original = doc([
      list([item('abc'), item('def')]),
    ]);
    final state = EditorState(
      doc: original,
      selection: const TextSelection(11),
    );
    final typing = commands.execute(state, 'insertText', {'text': '中'});
    final nested = typing.nestedReplacements.single;
    expect(nested.path, [0, 1, 0]);
    expect([nested.from, nested.oldTo, nested.newTo], [0, 1, 1]);
    expect(typing.replacedBlocks!.from, 0);
    expect(typing.replacedBlocks!.oldTo, 1);
    expect(typing.replacedBlocks!.newTo, 1);
    final split = commands.execute(state, 'splitListItem');
    final change = split.nestedReplacements.first;
    expect(change.path, [0]);
    expect([change.from, change.oldTo, change.newTo], [1, 2, 3]);
    final attr = state.tr.step(const AttrStep(0, 'test', true));
    expect(attr.nestedReplacements.single.path, isEmpty);
    expect(attr.nestedReplacements.single.oldTo, 1);
    final typed = state.apply(typing);
    final undo = commands.execute(typed, 'undo');
    expect(undo.nestedReplacements.single.path, [0, 1, 0]);
    final undone = typed.apply(undo);
    expect(commands.execute(undone, 'redo').nestedReplacements.single.path, [
      0,
      1,
      0,
    ]);
  });

  test('nested mark coverage respects mixed selections', () {
    final original = doc([
      list([
        schema.node(
          'listItem',
          content: [
            schema.node(
              'paragraph',
              content: [
                schema.node('text', text: 'abc', marks: [schema.mark('bold')]),
              ],
            ),
          ],
        ),
        item('def'),
      ]),
    ]);
    expect(
      EditorState(
        doc: original,
        selection: const TextSelection(3, 6),
      ).toolbar.activeMarks,
      {'bold'},
    );
    expect(
      EditorState(
        doc: original,
        selection: const TextSelection(3, 13),
      ).toolbar.activeMarks,
      isEmpty,
    );
    final tr = EditorState(
      doc: original,
      selection: const TextSelection(3, 13),
    ).tr.step(AddMarkStep(3, 13, schema.mark('underline')));
    expect(
      EditorState(
        doc: tr.doc,
        selection: const TextSelection(3, 13),
      ).toolbar.activeMarks,
      {'underline'},
    );
  });

  test('toolbar exposes nested wrapper and checked state', () {
    final original = doc([
      schema.node(
        'blockquote',
        content: [
          schema.node(
            'taskList',
            content: [
              schema.node(
                'taskItem',
                attrs: {'checked': true},
                content: [p('task')],
              ),
            ],
          ),
        ],
      ),
    ]);
    final toolbar = EditorState(
      doc: original,
      selection: const TextSelection(4),
    ).toolbar;
    expect(toolbar.activeNodes, {
      'blockquote',
      'taskList',
      'taskItem',
      'paragraph',
    });
    expect(toolbar.taskChecked, isTrue);
  });

  test('opaque blocks inside nested containers remain untouched by edits and history', () {
    final opaque = schema.fromJson({
      'type': 'table',
      'attrs': {
        'future': [true, 1],
      },
      'content': [
        {
          'type': 'tableRow',
          'content': [
            {'type': 'futureCell'},
          ],
        },
      ],
    });
    final original = doc([
      list([
        schema.node('listItem', content: [p('abc'), opaque]),
      ]),
    ]);
    var state = EditorState(doc: original, selection: const TextSelection(4));
    state = state.apply(commands.execute(state, 'insertText', {'text': '中'}));
    expect(identical(state.doc.child(0).child(0).child(1), opaque), isTrue);
    state = state.apply(commands.execute(state, 'undo'));
    expect(state.doc.toJson(), original.toJson());
    state = state.apply(commands.execute(state, 'redo'));
    expect(state.doc.child(0).child(0).child(1).toJson(), opaque.toJson());
  });

  test('row index and shared-tree differences survive splits, sinks, lifts and history', () {
    final original = generateLargeListDocument(items: 100);
    expect(original.rowCount, 200);
    for (var i = 0; i < 200; i++) {
      final row = original.rowAt(i);
      expect(original.rowIndexAt(row.position), i);
      expect(identical(original.nodeAt(row.position), row.node), isTrue);
    }
    final state = EditorState(
      doc: original,
      selection: TextSelection(original.rowAt(100).position + 4),
    );
    for (final name in [
      'insertText',
      'splitListItem',
      'sinkListItem',
      'liftListItem',
    ]) {
      final tr = commands.execute(
        state,
        name,
        name == 'insertText' ? {'text': '中'} : const {},
      );
      final range = original.changedRows(tr.doc);
      expect(range.from, 100, reason: name);
      expect(range.newTo - range.oldTo, tr.doc.rowCount - original.rowCount);
      expect(range.oldTo, lessThanOrEqualTo(102));
      if (name == 'insertText') expect(range.oldTo, 101);
      expect(tr.documents.first, same(original));
      expect(tr.documents.last, same(tr.doc));
    }
  });
}
