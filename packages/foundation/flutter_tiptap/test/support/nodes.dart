import 'package:flutter_tiptap/model.dart';

class TestNodes {
  TestNodes(this.schema);
  final Schema schema;

  Node p([String text = '']) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );

  Node doc(Iterable<Node> blocks, {Map<String, Object?>? attrs}) =>
      schema.node('doc', attrs: attrs, content: blocks);

  Node item(Iterable<Node> blocks) => schema.node('listItem', content: blocks);
  Node textItem(String text) => item([p(text)]);
  Node list(Iterable<Node> items) => schema.node('bulletList', content: items);
  Node cell(
    Iterable<Node> blocks, {
    bool header = false,
    Map<String, Object?>? attrs,
  }) => schema.node(
    header ? 'tableHeader' : 'tableCell',
    attrs: attrs,
    content: blocks,
  );
  Node textCell(String text) => cell([p(text)]);

  Node table(Iterable<Node> rows) => schema.node('table', content: rows);
  Node image(String name) => schema.node('image', attrs: {'src': name});
}
