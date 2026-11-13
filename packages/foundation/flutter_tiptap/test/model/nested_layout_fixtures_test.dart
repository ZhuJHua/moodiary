import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';
import 'package:moodiary_lint/testing.dart';

import '../support/large_doc.dart';

void main() {
  final schema = Schema.standard();
  final fixtures = Directory(
    '$repoRoot/packages/foundation/flutter_tiptap/test/fixtures/nested_layout',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));

  test('nested fixtures cover every schema container to child edge', () {
    final observed = <String>{};
    void visit(Node node) {
      expect(
        schema.validContent(node.type, node.content),
        isTrue,
        reason: node.type,
      );
      for (final child in node.content) {
        observed.add('${node.type} -> ${child.type}');
        visit(child);
      }
    }

    for (final file in fixtures) {
      final source = file.readAsStringSync();
      expect(
        source.codeUnits.any(
          (unit) => const [0x2028, 0x2029, 0x85].contains(unit),
        ),
        isFalse,
      );
      visit(schema.fromJson(jsonDecode(source) as Map<String, dynamic>));
    }
    final expected = <String>{};
    for (final type in schema.nodes.keys) {
      final visited = <ContentMatch>{};
      void edges(ContentMatch match) {
        if (!visited.add(match)) return;
        for (final (child, next) in match.next) {
          if (child != '@opaque') expected.add('$type -> $child');
          edges(next);
        }
      }

      edges(schema.contentMatch(type));
    }
    expect(expected.difference(observed), isEmpty);
    expect(observed.difference(expected), isEmpty);
  });

  for (final file in fixtures.where(
    (file) => file.uri.pathSegments.last.startsWith('rich_'),
  )) {
    test('${file.uri.pathSegments.last} covers rich multi-column cells', () {
      final doc = schema.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      final nodes = <Node>[];
      var tableDepth = 0;
      void visit(Node node, int depth) {
        nodes.add(node);
        final nextDepth = depth + (node.type == 'table' ? 1 : 0);
        if (nextDepth > tableDepth) tableDepth = nextDepth;
        for (final child in node.content) {
          visit(child, nextDepth);
        }
      }

      visit(doc, 0);
      final tables = nodes.where((node) => node.type == 'table');
      for (final table in tables) {
        final grid = TableMap.get(table);
        expect(grid.problems, isEmpty);
        final header = table.content.first;
        expect(header.content.length, inInclusiveRange(2, 4));
        expect(
          header.content.every((node) => node.type == 'tableHeader'),
          isTrue,
        );
        final richColumns = <int>{};
        var rowPosition = header.nodeSize;
        for (final row in table.content.skip(1)) {
          var cellPosition = rowPosition + 1;
          for (final cell in row.content) {
            if (cell.content.any((child) => child.type != 'paragraph')) {
              richColumns.add(grid.findCell(cellPosition).left);
            }
            cellPosition += cell.nodeSize;
          }
          rowPosition += row.nodeSize;
        }
        expect(richColumns.length, greaterThanOrEqualTo(2));
      }
      for (final kind in [
        'codeBlock',
        'bulletList',
        'orderedList',
        'taskList',
        'blockquote',
        'horizontalRule',
        'image',
        'video',
        'audio',
        'attachment',
      ]) {
        expect(nodes.any((node) => node.type == kind), isTrue, reason: kind);
      }
      expect(
        nodes
            .where((node) => node.type == 'image')
            .map(
              (node) => '${node.attrs['name']}:${node.attrs['widthPercent']}',
            )
            .toSet(),
        containsAll([
          'portrait:25',
          'portrait:50',
          'portrait:100',
          'landscape:25',
          'landscape:50',
          'landscape:100',
        ]),
      );
      expect(
        nodes.any(
          (node) =>
              node.type == 'codeBlock' &&
              (node.attrs['language'] as String).length > 40 &&
              node.textContent.split('\n').first.length < 20 &&
              node.textContent.split('\n').last.length > 300,
        ),
        isTrue,
      );
      expect(
        nodes.any(
          (node) =>
              node.type == 'orderedList' &&
              (node.attrs['start'] as int) >= 123456789,
        ),
        isTrue,
      );
      if (file.path.contains('spans') ||
          file.path.contains('list_tables') ||
          file.path.contains('quoted_tables') ||
          file.path.contains('depth_three')) {
        expect(
          nodes.any((node) => (node.attrs['colspan'] as int? ?? 1) > 1),
          isTrue,
        );
        expect(
          nodes.any((node) => (node.attrs['rowspan'] as int? ?? 1) > 1),
          isTrue,
        );
      }
      if (file.path.contains('quoted_tables')) {
        expect(doc.content.first.type, 'blockquote');
        expect(
          doc.content.first.content
              .where((node) => node.type == 'table')
              .map((node) => node.content.first.content.length),
          [2, 3, 4],
        );
      }
      if (file.path.contains('list_tables')) {
        expect(doc.content.first.type, 'bulletList');
        expect(
          doc.content.first.content.first.content
              .where((node) => node.type == 'table')
              .map((node) => node.content.first.content.length),
          [2, 3, 4],
        );
      }
      if (file.path.contains('depth_three')) expect(tableDepth, 3);
    });
  }

  test(
    'large mixed fixture has stable rows and localized edit differences',
    () {
      final doc = generateLargeMixedDocument(groups: 100);
      expect(doc.rowCount, greaterThan(500));
      final parsed = schema.parse(doc.toJsonString());
      expect(parsed.eq(doc), isTrue);
      final row = doc.rowAt(0);
      final state = EditorState(
        doc: doc,
        selection: TextSelection(row.position + 1),
      );
      final transaction = const EditorCommands().execute(state, 'insertText', {
        'text': 'x',
      });
      expect(transaction.doc.changedRows(doc), isNotNull);
      expect(transaction.doc.rowCount, doc.rowCount);
      expect(doc.rowAt(doc.rowCount - 1).node.textContent, 'Sentinel');
      expect(() => generateLargeMixedDocument(groups: 0), throwsArgumentError);
    },
  );
}
