import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';

import '../support/large_doc.dart';

int _referencePositionAt(Fragment content, int index) =>
    content.blocks?.positionAt(index) ??
    content.take(index).fold(0, (size, child) => size + child.nodeSize);

int _referenceIndexAt(Fragment content, int position) {
  if (content.blocks != null) return content.blocks!.indexAt(position);
  var offset = 0;
  for (var index = 0; index < content.length; index++) {
    if (offset + content[index].nodeSize > position) return index;
    offset += content[index].nodeSize;
  }
  return content.length;
}

int _referenceRowsBefore(Node node, int index) =>
    node.content.blocks?.summaryBetween(0, index).rowCount ?? 0;

int _referenceRowIndexAt(Node node, int position) {
  final resolved = node.resolve(position);
  var count = 0;
  for (var depth = 0; depth <= resolved.depth; depth++) {
    final parent = resolved.node(depth);
    if (parent.isTextblock || parent.isLeaf || parent.type == 'tableRow') {
      break;
    }
    count += _referenceRowsBefore(parent, resolved.index(depth));
  }
  return count.clamp(0, math.max(0, node.rowCount - 1));
}

DocumentRow _referenceRowAt(Node root, int row) {
  RangeError.checkValueInInterval(row, 0, root.rowCount - 1, 'row');
  var node = root, position = root.type == 'doc' ? -1 : 0;
  final path = <int>[];
  while (!node.isTextblock && !node.isLeaf && node.type != 'tableRow') {
    final (index, before) = node.blocks.childForRow(row);
    row -= before;
    position += 1 + node.content.positionAt(index);
    path.add(index);
    node = node.child(index);
  }
  return DocumentRow(node, position, List.unmodifiable(path));
}

Iterable<DocumentRow> _referenceRows(Node node, {int from = 0, int? to}) sync* {
  for (var index = from; index < (to ?? node.rowCount); index++) {
    yield _referenceRowAt(node, index);
  }
}

void _sameRow(DocumentRow actual, DocumentRow expected) {
  expect(identical(actual.node, expected.node), isTrue);
  expect(actual.position, expected.position);
  expect(actual.path, expected.path);
}

void _checkNode(Node node, {bool ranges = true}) {
  final content = node.content;
  expect(
    content.inlineText(),
    content.map((node) => node.text ?? '\ufffc').join(),
  );
  expect(
    content.inlineText(breaks: true),
    content
        .map(
          (node) => node.isText
              ? node.text!
              : node.type == 'hardBreak'
              ? '\n'
              : '\ufffc',
        )
        .join(),
  );
  expect(
    content.inlineText(atom: '\n'),
    content.map((node) => node.isText ? node.text! : '\n').join(),
  );
  final starts = <int>[0];
  for (final child in content) {
    starts.add(starts.last + child.nodeSize);
  }
  for (var index = 0; index <= node.childCount; index++) {
    expect(content.positionAt(index), _referencePositionAt(content, index));
    expect(content.positionAt(index), starts[index]);
    expect(node.rowsBefore(index), _referenceRowsBefore(node, index));
  }
  var childIndex = 0;
  for (var position = 0; position <= content.size; position++) {
    while (childIndex < node.childCount && starts[childIndex + 1] <= position) {
      childIndex++;
    }
    expect(content.indexAt(position), childIndex);
    expect(content.indexAt(position), _referenceIndexAt(content, position));
    expect(
      node.rowIndexAt(position),
      _referenceRowIndexAt(node, position),
      reason: '${node.type} at $position',
    );
  }
  final rows = node.rows().toList();
  final expected = _referenceRows(node).toList();
  expect(rows.length, expected.length);
  for (var index = 0; index < rows.length; index++) {
    _sameRow(rows[index], expected[index]);
    _sameRow(node.rowAt(index), expected[index]);
    if (ranges || index == 0 || index == rows.length - 1) {
      final end = math.min(index + 3, rows.length);
      final slice = node.rows(from: index, to: end).toList();
      expect(slice.length, end - index);
      for (var offset = 0; offset < slice.length; offset++) {
        _sameRow(slice[offset], expected[index + offset]);
      }
    }
  }
  for (final child in content) {
    _checkNode(child, ranges: ranges);
  }
}

void main() {
  test('grapheme helpers agree with sliced text at every UTF-16 offset', () {
    const text = 'a\u0301👩🏽‍💻\r\n🇨🇳\ufffc\nhello';
    for (var offset = 0; offset <= text.length; offset++) {
      if (offset > 0) {
        expect(
          graphemeBefore(text, offset),
          text.substring(0, offset).characters.last,
        );
      }
      if (offset < text.length) {
        expect(
          graphemeAfter(text, offset),
          text.substring(offset).characters.first,
        );
      }
    }
  });
  final generators = <String, Node Function()>{
    'text': () => generateLargeDocument(300000),
    'list': () => generateLargeListDocument(),
    'table': () => generateLargeTableDocument(),
    'mixed': () => generateLargeMixedDocument(),
  };
  for (final entry in generators.entries) {
    test('position helpers agree at every large ${entry.key} position', () {
      _checkNode(entry.value(), ranges: false);
    });
  }
}
