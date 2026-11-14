import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  final schema = ft.Schema.standard();
  final nodes = TestNodes(schema);

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
}
