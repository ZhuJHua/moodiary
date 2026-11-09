import 'dart:convert';
import 'dart:io';

import 'package:flutter_tiptap/model.dart';

import '../test/support/large_doc.dart';

double measure(void Function() work, {int repetitions = 101}) {
  for (var i = 0; i < 20; i++) {
    work();
  }
  final samples = <int>[];
  for (var i = 0; i < repetitions; i++) {
    final clock = Stopwatch()..start();
    work();
    clock.stop();
    samples.add(clock.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2] / 1000;
}

Future<void> main() async {
  final schema = Schema.standard();
  const commands = EditorCommands();
  for (final size in [1000000, 3000000]) {
    final generated = generateLargeDocument(size, schema: schema);
    if (generated.blocks.summary.textLength != size) {
      throw StateError('Incorrect generator budget');
    }
    final json = generated.toJsonString();
    final parse = measure(() {
      schema.parse(json);
    }, repetitions: 7);
    final doc = schema.parse(json);
    var index = doc.childCount ~/ 2;
    while (!doc.blocks[index].isTextblock) {
      index++;
    }
    final position =
        doc.blocks.positionAt(index) + 1 + doc.blocks[index].content.size ~/ 2;
    final initial = EditorState(doc: doc, selection: TextSelection(position));
    EditorState edit() =>
        initial.apply(commands.execute(initial, 'insertText', {'text': '中'}));
    final insert = measure(edit);
    final split = measure(() {
      initial.apply(commands.execute(initial, 'splitBlock'));
    });
    final splitState = initial.apply(commands.execute(initial, 'splitBlock'));
    final join = measure(() {
      splitState.apply(commands.execute(splitState, 'deleteBackward'));
    });
    var state = initial;
    final samples = <int>[];
    final sequential = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      final clock = Stopwatch()..start();
      state = state.apply(
        commands.execute(state, 'insertText', {'text': 'x'}),
        time: i,
      );
      clock.stop();
      samples.add(clock.elapsedMicroseconds);
    }
    sequential.stop();
    samples.sort();
    final undo = measure(() {
      state.apply(commands.execute(state, 'undo'));
    });
    final codec = DocumentCodec()..encode(doc);
    final encode = measure(() {
      codec.encode(edit().doc);
      if (codec.encodedBlocks != 1) {
        throw StateError('Full document re-encoded');
      }
    }, repetitions: 21);
    var checksum = 0;
    final resolve =
        measure(() {
          for (var i = 0; i < 1000; i++) {
            checksum += doc.resolve(position + i % 2).parentOffset;
          }
        }, repetitions: 101) /
        1000;
    if (checksum == 0) {
      throw StateError('Position resolution was not exercised');
    }
    stdout.writeln(
      jsonEncode({
        'characters': size,
        'blocks': doc.childCount,
        'treeHeight': doc.blocks.height,
        'parseMs': parse,
        'insertMs': insert,
        'splitMs': split,
        'joinMs': join,
        'keystrokeMedianMs': samples[500] / 1000,
        '1000KeystrokesMs': sequential.elapsedMicroseconds / 1000,
        'undoMs': undo,
        'incrementalJsonMs': encode,
        'resolveMs': resolve,
      }),
    );
    if (samples[500] > 10000 || encode > 1000) {
      throw StateError('Model performance regression');
    }
  }
  final doc = generateLargeListDocument(schema: schema);
  final list = doc.child(0), index = list.childCount ~/ 2;
  final position = 3 + list.content.positionAt(index) + 10;
  final initial = EditorState(doc: doc, selection: TextSelection(position));
  EditorState edit(String command) => initial.apply(
    commands.execute(
      initial,
      command,
      command == 'insertText' ? {'text': '中'} : const {},
    ),
  );
  final split = edit('splitListItem');
  final editedDoc = edit('insertText').doc;
  final nestedCodec = DocumentCodec()..encode(doc);
  final nestedSave = measure(() {
    nestedCodec.encode(edit('insertText').doc);
    if (nestedCodec.encodedNodes > 16) {
      throw StateError('Unchanged nested nodes re-encoded');
    }
  }, repetitions: 51);
  final rowChange = doc.changedRows(editedDoc);
  if (rowChange.oldTo - rowChange.from != 1 ||
      rowChange.newTo - rowChange.from != 1) {
    throw StateError('Keystroke invalidated unrelated nested rows');
  }
  final rowDiffMs = measure(() => doc.changedRows(editedDoc));
  final rowLookupMs =
      measure(() {
        for (var i = 0; i < 1000; i++) {
          doc.rowAt(10000 + i % 2);
        }
      }) /
      1000;
  final samples = <String, double>{
    for (final name in [
      'insertText',
      'splitListItem',
      'sinkListItem',
      'liftListItem',
    ])
      name: measure(() => edit(name)),
    'joinBackward': measure(
      () => split.apply(commands.execute(split, 'joinBackward')),
    ),
  };
  var state = initial;
  final clock = Stopwatch()..start();
  final keystrokes = <int>[];
  for (var i = 0; i < 1000; i++) {
    final stroke = Stopwatch()..start();
    state = state.apply(
      commands.execute(state, 'insertText', {'text': 'x'}),
      time: i,
    );
    keystrokes.add(stroke.elapsedMicroseconds);
  }
  clock.stop();
  keystrokes.sort();
  stdout.writeln(
    jsonEncode({
      'listItems': list.childCount,
      'incrementalJsonMs': nestedSave,
      'rows': doc.rowCount,
      'rowDiffMs': rowDiffMs,
      'rowLookupMs': rowLookupMs,
      'nested': true,
      'treeHeight': list.blocks.height,
      'operationsMs': samples,
      'keystrokeMedianMs': keystrokes[500] / 1000,
      '1000KeystrokesMs': clock.elapsedMicroseconds / 1000,
    }),
  );
  if (nestedSave >= 2) throw StateError('Nested JSON save exceeds 2ms');
  if (keystrokes[500] > 10000) {
    throw StateError('Nested list performance regression');
  }
  final mediaDoc = schema.node(
    'doc',
    content: [
      for (var i = 0; i < 1000; i++) ...[
        schema.node(
          'paragraph',
          content: [schema.node('text', text: 'x' * 1000)],
        ),
        schema.node('image', attrs: {'src': 'asset-$i', 'widthPercent': 75}),
      ],
      schema.node('paragraph'),
    ],
  );
  final mediaState = EditorState(
    doc: mediaDoc,
    selection: const TextSelection(502001),
  );
  final mediaEdit = commands.execute(mediaState, 'insertText', {'text': '中'});
  final mediaDiff = mediaDoc.changedRows(mediaEdit.doc);
  if (mediaDiff.newTo - mediaDiff.from != 1) {
    throw StateError('Media document invalidates other rows');
  }
  stdout.writeln(
    jsonEncode({
      'mediaAtoms': 1000,
      'characters': mediaDoc.textLength,
      'rows': mediaDoc.rowCount,
      'keystrokeMedianMs': measure(
        () => mediaState.apply(
          commands.execute(mediaState, 'insertText', {'text': '中'}),
        ),
      ),
      'rowDiffMs': measure(() => mediaDoc.changedRows(mediaEdit.doc)),
      'selectAndResizeMs': measure(() {
        final selected = EditorState(
          doc: mediaDoc,
          selection: NodeSelection(mediaDoc, 1002),
        );
        commands.execute(selected, 'setMediaWidth', {'percent': 50});
      }),
    }),
  );
  final searchDoc = generateLargeDocument(3000000),
      search = SearchIndex(query: '日记');
  final cold = Stopwatch()..start();
  final matches = search.findAll(searchDoc);
  cold.stop();
  final searchState = EditorState(
    doc: searchDoc,
    selection: const TextSelection(20),
  );
  final searchEdited = commands.execute(searchState, 'insertText', {
    'text': '中',
  }).doc;
  final scanned = search.scannedBlocks;
  final incrementalSearch = measure(() => search.findAll(searchEdited));
  stdout.writeln(
    jsonEncode({
      'searchCharacters': 3000000,
      'matches': matches.length,
      'coldSearchMs': cold.elapsedMicroseconds / 1000,
      'cachedSearchMs': measure(() => search.findAll(searchDoc)),
      'incrementalSearchMs': incrementalSearch,
      'rescannedBlocks': search.scannedBlocks - scanned,
    }),
  );
  final asyncSearch = SearchIndex(query: '日记'),
      slice = Stopwatch()..start(),
      asyncClock = Stopwatch()..start();
  var maxSlice = 0, yields = 0;
  for (final row in searchDoc.rows()) {
    await asyncSearch.prepare(
      row.node,
      slice,
      onYield: () {
        yields++;
        if (slice.elapsedMicroseconds > maxSlice) {
          maxSlice = slice.elapsedMicroseconds;
        }
      },
    );
  }
  stdout.writeln(
    jsonEncode({
      'asyncSearchCharacters': 3000000,
      'totalMs': asyncClock.elapsedMicroseconds / 1000,
      'maxSliceMs': maxSlice / 1000,
      'yields': yields,
    }),
  );
  final tableDoc = generateLargeTableDocument(),
      table = tableDoc.child(0),
      map = TableMap.get(table),
      cell = map.map[1000 * map.width] + 1;
  final tableState = EditorState(
    doc: tableDoc,
    selection: TextSelection(cell + 2),
  );
  final tableEdit = commands.execute(tableState, 'insertText', {'text': '中'});
  final tableCodec = DocumentCodec()..encode(tableDoc);
  stdout.writeln(
    jsonEncode({
      'tableRows': 2000,
      'documentRows': tableDoc.rowCount,
      'tableMapMs': measure(() => TableMap.get(table)),
      'cellEditMs': measure(
        () => commands.execute(tableState, 'insertText', {'text': '中'}),
      ),
      'addRowMs': measure(() => commands.execute(tableState, 'addRowAfter')),
      'addColumnMs': measure(
        () => commands.execute(tableState, 'addColumnAfter'),
        repetitions: 11,
      ),
      'rowDiffMs': measure(() => tableDoc.changedRows(tableEdit.doc)),
      'incrementalJsonMs': measure(
        () => tableCodec.encode(
          commands.execute(tableState, 'insertText', {'text': '中'}).doc,
        ),
      ),
    }),
  );
}
