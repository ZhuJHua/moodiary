import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';

import '../support/large_doc.dart';

void main() {
  final schema = Schema.standard();
  const commands = EditorCommands(trailingParagraph: true);
  test('merged grid, rectangles, clipping and identity cache', () {
    final table = createTable(schema, rows: 3, columns: 3),
        doc = schema.node('doc', content: [table, schema.node('paragraph')]);
    final map = TableMap.get(table);
    expect(TableMap.get(table), same(map));
    expect(map.width, 3);
    expect(map.height, 3);
    expect(map.problems, isEmpty);
    final selection = CellSelection(doc, map.map[0] + 1, map.map[4] + 1);
    final slice = selection.content(doc);
    expect(slice.openStart, 1);
    expect(slice.content.length, 2);
    expect(slice.content.first.childCount, 2);
    var state = EditorState(doc: doc, selection: selection);
    state = state.apply(commands.execute(state, 'mergeCells'), time: 0);
    final merged = state.doc.child(0), grid = TableMap.get(merged);
    expect(grid.map[0], grid.map[1]);
    expect(grid.map[0], grid.map[3]);
    expect(grid.findCell(grid.map[0]).bottom, 2);
    expect(grid.problems, isEmpty);
    state = state.apply(commands.execute(state, 'splitCell'), time: 1000);
    expect(TableMap.get(state.doc.child(0)).map.toSet(), hasLength(9));
    state = state.apply(commands.execute(state, 'undo'));
    expect(state.doc.child(0).toJson(), merged.toJson());
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
  test(
    'replace all is one isolated undo and scans only the changed textblock',
    () {
      var state = EditorState(doc: generateLargeDocument(3000000));
      final query = SearchIndex(query: '日记');
      query.findAll(state.doc);
      final scanned = query.scannedBlocks;
      final before = state.doc;
      state = state.apply(commands.execute(state, 'insertText', {'text': '中'}));
      query.findAll(state.doc);
      expect(query.scannedBlocks - scanned, 1);
      final edited = state.doc;
      state = state.apply(query.replaceAll(state, 'xy'));
      expect(query.findAll(state.doc), isEmpty);
      state = state.apply(commands.execute(state, 'undo'));
      expect(state.doc, same(edited));
      state = state.apply(commands.execute(state, 'undo'));
      expect(state.doc, same(before));
    },
  );
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
