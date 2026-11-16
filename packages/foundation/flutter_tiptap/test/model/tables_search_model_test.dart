import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';

import '../support/large_doc.dart';

void main() {
  final schema = Schema.standard();
  const commands = EditorCommands(trailingParagraph: true);
  test('existing merged cells normalize, round trip and edit as text', () {
    final codec = TiptapHtmlCodec(schema);
    final doc = codec.parse(
      '<table><tr><th colspan="2" rowspan="2"><p>merged</p></th>'
      '<td><p>a</p></td></tr><tr><td><p>b</p></td></tr>'
      '<tr><td><p>c</p></td><td><p>d</p></td><td><p>e</p></td></tr></table>'
      '<p></p>',
    );
    final table = doc.child(0), map = TableMap.get(table);
    expect(TableMap.get(table), same(map));
    expect(map.width, 3);
    expect(map.height, 3);
    expect(map.problems, isEmpty);
    expect(map.map[0], map.map[1]);
    expect(map.map[0], map.map[3]);
    expect(map.findCell(map.map[0]).bottom, 2);
    expect(fixTables(doc).toJson(), doc.toJson());
    expect(schema.parse(doc.toJsonString()).toJson(), doc.toJson());
    expect(codec.parse(codec.serialize(doc)).toJson(), doc.toJson());
    var state = EditorState(doc: doc, selection: const TextSelection(4, 10));
    state = state.apply(
      commands.execute(state, 'insertText', {'text': 'edit'}),
    );
    expect(state.doc.child(0).child(0).child(0).textContent, 'edit');
    expect(TableMap.get(state.doc.child(0)).problems, isEmpty);
    state = state.apply(commands.execute(state, 'undo'));
    expect(state.doc.toJson(), doc.toJson());
    expect(state.selection, const TextSelection(4, 10));
  });
  test('text ranges clamp in both directions and retain their anchor', () {
    final doc = generateLargeTableDocument(rows: 2, columns: 2);
    final map = TableMap.get(doc.child(0));
    final cell = map.map[1] + 1;
    final start = cell + 2, end = cell + doc.nodeAt(cell)!.nodeSize - 2;
    final state = EditorState(doc: doc);
    for (final anchor in [start, start + 2, end]) {
      expect(
        state.tr.setSelection(TextSelection(anchor, 4)).selection,
        TextSelection(anchor, start),
      );
      expect(
        state.tr
            .setSelection(TextSelection(anchor, doc.content.size))
            .selection,
        TextSelection(anchor, end),
      );
      expect(
        state.tr.setSelection(TextSelection(anchor, end - 1)).selection,
        TextSelection(anchor, end - 1),
      );
    }
  });
  test('clamping includes all paragraphs in a cell and empty cells', () {
    final doc = TiptapHtmlCodec(schema).parse(
      '<table><tr><td><p>first</p><blockquote><p>last</p></blockquote></td>'
      '<td><p></p></td></tr></table><p>after</p>',
    );
    final state = EditorState(doc: doc);
    final cell = doc.child(0).child(0).child(0);
    final end = cell.nodeSize - 1;
    expect(
      state.tr.setSelection(TextSelection(5, doc.content.size)).selection,
      TextSelection(5, end),
    );
    final empty = TableMap.get(doc.child(0)).map[1] + 3;
    expect(
      state.tr.setSelection(TextSelection(empty, 4)).selection,
      TextSelection(empty),
    );
  });
  test('selections anchored outside tables can include a whole table', () {
    final doc = TiptapHtmlCodec(schema).parse(
      '<p>before</p><table><tr><td><p>cell</p></td></tr></table><p>after</p>',
    );
    final state = EditorState(doc: doc);
    final selection = TextSelection(1, doc.content.size - 1);
    expect(state.tr.setSelection(selection).selection, selection);
    final tableSelection = NodeSelection(doc, doc.child(0).nodeSize);
    expect(state.tr.setSelection(tableSelection).selection, tableSelection);
    expect(
      state.tr.setSelection(AllSelection(doc)).selection,
      AllSelection(doc),
    );
    final deleted = state.apply(
      commands.execute(
        EditorState(doc: doc, selection: selection),
        'deleteBackward',
      ),
    );
    expect(deleted.doc.textContent, '');
    expect(
      deleted.apply(commands.execute(deleted, 'undo')).doc.toJson(),
      doc.toJson(),
    );
  });
  test(
    'cell boundaries isolate backspace/delete and empty Enter stays inside',
    () {
      var state = EditorState(
        doc: generateLargeTableDocument(rows: 2, columns: 2),
      );
      final first = tableContext(state.doc, state.selection.head)!;
      state = state.apply(commands.execute(state, 'deleteBackward'));
      expect(
        tableContext(state.doc, state.selection.head)!.cellPosition,
        first.cellPosition,
      );
      state = state.apply(
        commands.execute(state, 'setTextSelection', {
          'anchor': first.cellPosition + 2,
          'head': first.cellPosition + first.cell.nodeSize - 2,
        }),
      );
      state = state.apply(commands.execute(state, 'deleteBackward'));
      final before = state.doc.rowCount;
      state = state.apply(commands.execute(state, 'splitBlock'));
      expect(state.doc.rowCount, before);
      expect(tableContext(state.doc, state.selection.head)!.cell.childCount, 2);
    },
  );
  test('replace all is one isolated undo', () {
    var state = EditorState(doc: generateLargeDocument(3000000));
    final query = SearchIndex(query: '日记');
    query.findAll(state.doc);
    final before = state.doc;
    state = state.apply(commands.execute(state, 'insertText', {'text': '中'}));
    query.findAll(state.doc);
    final edited = state.doc;
    state = state.apply(query.replaceAll(state, 'xy'));
    expect(query.findAll(state.doc), isEmpty);
    state = state.apply(commands.execute(state, 'undo'));
    expect(state.doc, same(edited));
    state = state.apply(commands.execute(state, 'undo'));
    expect(state.doc, same(before));
  });
  test('search status enumeration is non-overlapping while backwards navigation overlaps', () {
    final doc = schema.node(
      'doc',
      content: [
        schema.node(
          'paragraph',
          content: [schema.node('text', text: 'aaaa 中文中文')],
        ),
      ],
    );
    final query = SearchIndex(query: 'aa');
    expect(query.findAll(doc).map((m) => m.from), [1, 3]);
    expect(query.findPrev(doc, 4)!.from, 2);
    expect(SearchIndex(query: '中文').findAll(doc).map((m) => m.from), [6, 8]);
  });
}
