import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

void main() {
  final schema = Schema.standard();
  final codec = TiptapHtmlCodec(schema);
  const commands = EditorCommands(trailingParagraph: true);

  EditorState pasteHtml(EditorState state, String html) => state.apply(
    commands.execute(state, 'pasteSlice', {'slice': codec.parseSlice(html)}),
  );

  List<Node> linked(Node node) => [
    if (node.isText && node.marks.any((mark) => mark.type == 'link')) node,
    for (final child in node.content) ...linked(child),
  ];

  test('shrinking a table selection with an external rule does not throw', () {
    final doc = codec.parse('<table><tr><td>a</td></tr></table><p>b</p>');
    final state = EditorState(doc: doc, selection: const TextSelection(4, 11));
    final result = pasteHtml(state, '<hr>');
    expect(result.doc.content.size, lessThan(state.selection.from));
    expect(result.doc.blocks.map((node) => node.type), [
      'horizontalRule',
      'paragraph',
    ]);
    final undone = result.apply(commands.execute(result, 'undo'));
    expect(undone.doc.eq(doc), true);
    expect(undone.history.canUndo, false);
  });

  test('random selections and HTML fragments paste without exceptions', () {
    const sources = [
      '<p>before example.com after</p>',
      '<table><tr><td>a</td><td>b</td></tr></table><p>after</p>',
      '<blockquote><p>quote</p></blockquote><h2>heading</h2>',
      '<ul><li><p>first</p></li><li><p>second</p></li></ul>',
      '<p>before</p><pre><code>code.com</code></pre><p>after</p>',
    ];
    const fragments = [
      '<hr>',
      '',
      '<p>visit example.com</p>',
      '<p>one</p><p>two.com</p>',
      '<table><tr><td>cell.com</td></tr></table>',
      '<blockquote><p>quote.com</p></blockquote>',
      '<pre><code>code.com</code></pre>',
      '<ul><li><p>item.com</p></li></ul>',
    ];
    final random = Random(29);
    for (final source in sources) {
      final doc = codec.parse(source);
      for (final fragment in fragments) {
        for (var iteration = 0; iteration < 12; iteration++) {
          final anchor = random.nextInt(doc.content.size + 1);
          final head = random.nextInt(doc.content.size + 1);
          final state = EditorState(
            doc: doc,
            selection: TextSelection(anchor, head),
          );
          expect(
            () {
              final result = pasteHtml(state, fragment);
              expect(
                result.selection.from,
                inInclusiveRange(0, result.doc.content.size),
              );
              expect(
                result.selection.to,
                inInclusiveRange(0, result.doc.content.size),
              );
            },
            returnsNormally,
            reason: '$source selection $anchor..$head with $fragment',
          );
        }
      }
    }
  });

  test('pasted table textblocks link URLs while preserving links and code', () {
    final state = EditorState(doc: codec.parse('<p></p>'));
    final result = pasteHtml(
      state,
      '<table><tr><td><p>visit example.com</p>'
      '<p><a href="https://keep.test/path">keep.com</a> '
      '<code>inline.com</code></p><pre><code>block.com</code></pre></td>'
      '<td><p><strong>second.com</strong></p></td></tr></table>',
    );
    final links = linked(result.doc);
    expect(links.map((node) => node.text), [
      'example.com',
      'keep.com',
      'second.com',
    ]);
    expect(
      links.map(
        (node) =>
            node.marks.firstWhere((mark) => mark.type == 'link').attrs['href'],
      ),
      ['http://example.com', 'https://keep.test/path', 'http://second.com'],
    );
    expect(links.last.marks.map((mark) => mark.type), contains('bold'));
    final undone = result.apply(commands.execute(result, 'undo'));
    expect(undone.doc.eq(state.doc), true);
    expect(undone.history.canUndo, false);
  });

  test('HTML pasted inside a table cell links only the inserted range', () {
    final doc = codec.parse(
      '<table><tr><td>before after.com</td></tr></table>',
    );
    final state = EditorState(doc: doc, selection: const TextSelection(11));
    final result = pasteHtml(state, '<p>visit example.com</p>');
    expect(result.doc.textContent, 'before visit example.comafter.com');
    expect(linked(result.doc).map((node) => node.text), ['example.com']);
    expect(
      linked(result.doc).single.marks.single.attrs['href'],
      'http://example.com',
    );
    final undone = result.apply(commands.execute(result, 'undo'));
    expect(undone.doc.eq(doc), true);
  });

  test('a rejected URI pasted over a selection inserts literal text', () {
    final state = EditorState(
      doc: codec.parse('<p>label</p>'),
      selection: const TextSelection(1, 6),
    );
    final result = state.apply(
      commands.execute(state, 'pasteText', {'text': 'file:///tmp/a.txt'}),
    );
    expect(result.doc.textContent, 'file:///tmp/a.txt');
    expect(linked(result.doc), isEmpty);
    final undone = result.apply(commands.execute(result, 'undo'));
    expect(undone.doc.eq(state.doc), true);
    expect(undone.history.canUndo, false);
  });

  test('link-on-paste validates the resulting href for a host and port', () {
    final state = EditorState(
      doc: codec.parse('<p>label</p>'),
      selection: const TextSelection(1, 6),
    );
    final result = state.apply(
      commands.execute(state, 'pasteText', {'text': 'localhost:3000'}),
    );
    expect(result.doc.textContent, 'label');
    expect(
      linked(result.doc).single.marks.single.attrs['href'],
      'https://localhost:3000',
    );
  });
}
