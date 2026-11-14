import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final nodes = TestNodes(schema);

  ft.Node document() => nodes.doc([
    nodes.p(),
    nodes.list([
      nodes.textItem('one'),
      nodes.item([
        nodes.p('two'),
        nodes.list([nodes.textItem('three')]),
      ]),
    ]),
    nodes.table([
      schema.node(
        'tableRow',
        content: [nodes.textCell('cell'), nodes.textCell('other')],
      ),
    ]),
    nodes.image('image.jpg'),
    nodes.p('last'),
  ]);

  test('row positions descend without resolving text selections', () {
    final doc = document();
    final expected = <int>[];
    for (var position = 0; position <= doc.content.size; position++) {
      final resolved = doc.resolve(position);
      var count = 0;
      for (var depth = 0; depth <= resolved.depth; depth++) {
        final parent = resolved.node(depth);
        if (parent.isTextblock || parent.isLeaf || parent.type == 'tableRow') {
          break;
        }
        count += parent.content
            .take(resolved.index(depth))
            .fold(0, (sum, child) => sum + child.rowCount);
      }
      expected.add(count.clamp(0, doc.rowCount - 1));
    }
    ft.ResolvedPos.debugResolutions = 0;
    expect([
      for (var position = 0; position <= doc.content.size; position++)
        doc.rowIndexAt(position),
    ], expected);
    expect(ft.ResolvedPos.debugResolutions, 0);
  });

  test('row iteration preserves paths and ranges without indexed lookups', () {
    final doc = document();
    final expected = [
      for (var index = 0; index < doc.rowCount; index++) doc.rowAt(index),
    ];
    ft.Node.debugRowLookups = 0;
    final rows = doc.rows().toList();
    final slice = doc.rows(from: 1, to: doc.rowCount - 1).toList();
    expect(ft.Node.debugRowLookups, 0);
    expect(rows.map((row) => row.node), expected.map((row) => row.node));
    expect(
      rows.map((row) => row.position),
      expected.map((row) => row.position),
    );
    expect(rows.map((row) => row.path), expected.map((row) => row.path));
    expect(
      slice.map((row) => row.node),
      rows.skip(1).take(rows.length - 2).map((row) => row.node),
    );
    expect(doc.rows(from: 3, to: 3), isEmpty);
  });

  test('bounded selected text stops visiting inline nodes at its limit', () {
    final doc = schema.node(
      'doc',
      content: [
        schema.node(
          'paragraph',
          content: [
            for (var index = 0; index < 2000; index++)
              schema.node(
                'text',
                text: '$index ',
                marks: [schema.mark(index.isEven ? 'bold' : 'italic')],
              ),
          ],
        ),
      ],
    );
    final controller = ft.TiptapController(doc: doc);
    addTearDown(controller.dispose);
    controller.setSelection(ft.TextSelection(1, doc.content.size - 1));
    final full = controller.selectedText;
    controller.diagnostics.selectedTextNodes = 0;
    expect(
      controller.selectedTextPrefix(maxLength: 200),
      full.substring(0, 200),
    );
    expect(controller.diagnostics.selectedTextNodes, lessThan(100));
    expect(controller.selectedTextPrefix(maxLength: 0), '');
  });

  test('selected text prefixes retain empty rows and atom placeholders', () {
    final doc = nodes.doc([
      nodes.p(),
      nodes.p('text'),
      nodes.image('image.jpg'),
      nodes.p('last'),
    ]);
    final controller = ft.TiptapController(doc: doc);
    addTearDown(controller.dispose);
    controller.setSelection(ft.TextSelection(0, doc.content.size));
    expect(controller.selectedText, '\ntext\n\ufffc\nlast');
    for (var length = 0; length <= controller.selectedText.length; length++) {
      expect(
        controller.selectedTextPrefix(maxLength: length),
        controller.selectedText.substring(0, length),
      );
    }
  });

  test(
    'search progress and clearing do not notify document listeners',
    () async {
      final controller = ft.TiptapController(
        doc: nodes.doc([
          for (var index = 0; index < 400; index++) nodes.p('needle $index'),
        ]),
      );
      addTearDown(controller.dispose);
      var documents = 0, progress = 0;
      controller.addListener(() => documents++);
      controller.searchStatus.addListener(() => progress++);
      controller.startSearch('needle');
      await controller.searchComplete;
      expect(controller.searchStatus.value.total, 400);
      expect(progress, greaterThanOrEqualTo(2));
      expect(documents, 1);
      controller.clearSearch();
      expect(documents, 1);
    },
  );

  test(
    'prepared search rows return synchronously without rescanning',
    () async {
      final index = ft.SearchIndex(query: 'text'), node = nodes.p('text text');
      await index.prepare(node, Stopwatch()..start());
      final scanned = index.scannedBlocks;
      expect(index.prepare(node, Stopwatch()..start()), isNull);
      expect(index.scannedBlocks, scanned);
      expect(index.matches(node), hasLength(2));
    },
  );

  test(
    'replace all consumes supplied matches without a document scan',
    () async {
      final doc = nodes.doc([nodes.p('one one')]);
      final index = ft.SearchIndex(query: 'one');
      final matches = index.findAll(doc);
      final scans = index.documentScans;
      final transaction = await index.replaceAllAsync(
        ft.EditorState(doc: doc),
        r'[$&] $$',
        matches: matches,
      );
      expect(index.documentScans, scans);
      expect(transaction.doc.textContent, r'[one] $ [one] $');
    },
  );

  for (final initial in <ft.Node>[
    nodes.doc([nodes.p('before after')]),
    nodes.doc([
      nodes.list([nodes.textItem('before after')]),
    ]),
    nodes.doc([
      schema.node(
        'codeBlock',
        content: [schema.node('text', text: 'before after')],
      ),
    ]),
    nodes.doc([
      schema.node(
        'heading',
        attrs: {'level': 2},
        content: [schema.node('text', text: 'before after')],
      ),
    ]),
  ]) {
    test(
      'committed lines preserve splitting and undo in ${initial.child(0).type}',
      () {
        final controller = ft.TiptapController(doc: initial),
            reference = ft.TiptapController(doc: initial);
        addTearDown(controller.dispose);
        addTearDown(reference.dispose);
        final start = initial.rows().first.position + 4;
        controller.setSelection(ft.TextSelection(start, start + 2));
        reference.setSelection(ft.TextSelection(start, start + 2));
        var notifications = 0;
        controller.addListener(() => notifications++);
        const text = 'alpha\n\nbeta\n';
        if (reference.state.doc
                .resolve(reference.state.selection.from)
                .parent
                .type ==
            'codeBlock') {
          reference.apply(
            reference.commands.execute(reference.state, 'insertText', {
              'text': text,
              'committed': false,
              'composition': 'reference',
            })..setMeta('closeHistory', true),
          );
        } else {
          final parts = text.split('\n');
          for (var index = 0; index < parts.length; index++) {
            if (index > 0) reference.exec('splitBlock');
            if (parts[index].isNotEmpty || !reference.state.selection.empty) {
              reference.exec('insertText', {
                'text': parts[index],
                'committed': false,
              });
            }
          }
        }
        controller.insertPlainText(text);
        expect(controller.state.doc.eq(reference.state.doc), isTrue);
        expect(controller.state.selection, reference.state.selection);
        expect(notifications, 1);
        controller.exec('undo');
        expect(controller.state.doc.eq(initial), isTrue);
        expect(controller.state.selection, ft.TextSelection(start, start + 2));
      },
    );
  }

  test('platform block styles reuse resolved font fallback lists', () {
    final old = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = old);
    const style = ft.TiptapEditorStyle();
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      for (final node in [
        nodes.p('text'),
        schema.node('heading', attrs: {'level': 2}),
        schema.node('codeBlock'),
      ]) {
        final resolved = style.forBlock(node);
        expect(identical(resolved, style.forBlock(node)), isTrue);
        expect(
          identical(
            resolved.fontFamilyFallback,
            style.forBlock(node).fontFamilyFallback,
          ),
          isTrue,
        );
      }
    }
  });
}
