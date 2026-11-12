import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

void main() {
  final schema = Schema.standard();
  Node paragraph(String text) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  Node code(String text) => schema.node(
    'codeBlock',
    attrs: {'language': 'dart'},
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  final containers = <String, Node Function(Node)>{
    'document': (block) => schema.node('doc', content: [block]),
    'list item': (block) => schema.node(
      'doc',
      content: [
        schema.node(
          'bulletList',
          content: [
            schema.node('listItem', content: [paragraph('item'), block]),
          ],
        ),
      ],
    ),
    'blockquote': (block) => schema.node(
      'doc',
      content: [
        schema.node('blockquote', content: [block]),
      ],
    ),
    'table cell': (block) => schema.node(
      'doc',
      content: [
        schema.node(
          'table',
          content: [
            schema.node(
              'tableRow',
              content: [
                schema.node('tableCell', content: [block]),
                schema.node('tableCell', content: [paragraph('other')]),
              ],
            ),
          ],
        ),
      ],
    ),
  };

  int? codeStart(Node node, [int position = -1]) {
    if (node.type == 'codeBlock') return position + 1;
    var offset = position + 1;
    for (final child in node.content) {
      final found = codeStart(child, offset);
      if (found != null) return found;
      offset += child.nodeSize;
    }
    return null;
  }

  for (final container in containers.entries) {
    for (final (indent, text) in [
      ('plain', 'value'),
      ('spaces', '  value'),
      ('tabs', '\tvalue'),
    ]) {
      test(
        'third Enter exits code with $indent inside ${container.key} in one undo step',
        () {
          final controller = TiptapController(doc: container.value(code(text)));
          addTearDown(controller.dispose);
          final start = codeStart(controller.state.doc)!;
          controller.setSelection(TextSelection(start + text.length));
          controller.exec('splitBlock');
          controller.exec('splitBlock');
          final before = controller.state;
          final resolved = before.doc.resolve(before.selection.from);
          final parentDepth = resolved.depth - 1;
          final parentPath = List.generate(
            parentDepth,
            (depth) => resolved.index(depth),
          );
          final codeIndex = resolved.index(parentDepth);

          controller.exec('splitBlock');

          final after = controller.state;
          final caret = after.doc.resolve(after.selection.from);
          final parent = caret.node(parentDepth);
          expect(caret.parent.type, 'paragraph');
          expect(caret.parent.content.isEmpty, isTrue);
          expect(caret.parentOffset, 0);
          expect(after.selection.empty, isTrue);
          expect(
            List.generate(parentDepth, (depth) => caret.index(depth)),
            parentPath,
          );
          expect(parent.child(codeIndex).type, 'codeBlock');
          expect(parent.child(codeIndex).textContent, text);
          expect(parent.child(codeIndex).attrs['language'], 'dart');
          expect(parent.child(codeIndex + 1).type, 'paragraph');
          if (container.key == 'table cell') {
            expect(after.doc.child(0).child(0).child(1).textContent, 'other');
          }

          controller.exec('undo');
          expect(controller.state.doc.toJson(), before.doc.toJson());
          expect(controller.state.selection, before.selection);
          controller.exec('redo');
          expect(controller.state.doc.toJson(), after.doc.toJson());
          expect(controller.state.selection, after.selection);
        },
      );
    }
  }

  for (final text in [
    '  value\n  next\n  ',
    '\tvalue\n\tnext\n\t',
    '  value\n  \n  next',
    '\tvalue\n\t\n\tnext',
  ]) {
    test('Enter keeps a non-empty trailing line in code ${text.codeUnits}', () {
      final controller = TiptapController(
        doc: containers['document']!(code(text)),
      );
      addTearDown(controller.dispose);
      controller.setSelection(TextSelection(text.length + 1));
      controller.exec('splitBlock');
      expect(controller.state.doc.child(0).type, 'codeBlock');
      expect(controller.state.doc.child(0).textContent, startsWith('$text\n'));
      expect(
        controller.state.doc
            .resolve(controller.state.selection.from)
            .parent
            .type,
        'codeBlock',
      );
    });
  }

  for (final plain in [false, true]) {
    test(
      'code paste normalizes CRLF and CR before Enter exit, plain: $plain',
      () {
        final controller = TiptapController(
          doc: containers['document']!(code('')),
        );
        addTearDown(controller.dispose);
        controller.setSelection(const TextSelection(1));
        controller.exec('pasteText', {
          'text': 'value\r\nnext\r',
          'plain': plain,
        });
        expect(controller.state.doc.child(0).textContent, 'value\nnext\n');
        expect(controller.state.selection, const TextSelection(12));
        controller.exec('splitBlock');
        final beforeExit = controller.state;
        controller.exec('splitBlock');
        expect(controller.state.doc.child(0).textContent, 'value\nnext');
        expect(controller.state.doc.child(1).type, 'paragraph');
        expect(controller.state.selection, const TextSelection(13));
        expect(controller.state.doc.textContent, isNot(contains('\r')));
        controller.exec('undo');
        expect(controller.state.doc.toJson(), beforeExit.doc.toJson());
        expect(controller.state.selection, beforeExit.selection);
      },
    );
  }

  for (final (text, offset, end, expected) in [
    ('value', 5, 5, 'value\n'),
    ('value\n', 6, 6, 'value\n\n'),
    ('value\n\n', 2, 2, 'va\nlue\n\n'),
    ('value\n\n', 5, 7, 'value\n'),
    ('  value', 7, 7, '  value\n  '),
  ]) {
    test('Enter inserts a newline in $text at $offset..$end', () {
      final controller = TiptapController(
        doc: containers['document']!(code(text)),
      );
      addTearDown(controller.dispose);
      controller.setSelection(TextSelection(offset + 1, end + 1));
      controller.exec('splitBlock');
      expect(controller.state.doc.child(0).type, 'codeBlock');
      expect(controller.state.doc.child(0).textContent, expected);
      expect(
        controller.state.doc
            .resolve(controller.state.selection.from)
            .parent
            .type,
        'codeBlock',
      );
    });
  }

  test('explicit code exit preserves trailing newlines', () {
    final controller = TiptapController(
      doc: containers['document']!(code('value\n\n')),
    );
    addTearDown(controller.dispose);
    controller.setSelection(const TextSelection(8));
    controller.exec('exitCode');
    expect(controller.state.doc.child(0).textContent, 'value\n\n');
    expect(controller.state.doc.child(1).type, 'paragraph');
    expect(controller.state.selection, const TextSelection(10));
  });
}
