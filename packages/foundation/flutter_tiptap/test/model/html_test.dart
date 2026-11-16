import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

import '../support/nodes.dart';

void main() {
  final schema = Schema.standard();

  Node docWith(Node paragraph) => schema.node('doc', content: [paragraph]);
  final text = TestNodes(schema).p;
  const heading = <String, dynamic>{
    'type': 'doc',
    'content': [
      {
        'type': 'heading',
        'attrs': {'level': 1},
        'content': [
          {'type': 'text', 'text': 'Title'},
        ],
      },
    ],
  };
  test('HTML without formatting goes through the text hook', () async {
    final c = TiptapController(doc: docWith(schema.node('paragraph')));
    addTearDown(c.dispose);
    var calls = 0;
    Map<String, dynamic> convert(String _) {
      calls++;
      return heading;
    }

    await c.pasteHtml('<p># Title</p>', text: '# Title', onPasteText: convert);
    expect(calls, 1);
    expect(c.state.doc.child(0).type, 'heading');
    c.exec('undo');
    expect(c.state.doc.child(0).type, 'paragraph');
    expect(c.state.doc.textContent, '');

    await c.pasteHtml(
      '<p><strong># Title</strong></p>',
      text: '# Title',
      onPasteText: convert,
    );
    expect(calls, 1);
    expect(c.state.doc.child(0).content.first.marks.single.type, 'bold');

    c.replaceDocument(docWith(schema.node('paragraph')));
    await c.pasteHtml('<p>plain</p>', text: 'plain', onPasteText: (_) => null);
    expect(c.state.doc.textContent, 'plain');
  });
  test('a converted lone paragraph joins the text around the caret', () async {
    final c = TiptapController(doc: docWith(text('ab')));
    addTearDown(c.dispose);
    c.setSelection(const TextSelection(2));
    await c.paste(
      text: '**x**',
      onPasteText: (_) => {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'text',
                'text': 'x',
                'marks': [
                  {'type': 'bold'},
                ],
              },
            ],
          },
        ],
      },
    );
    expect(c.state.doc.childCount, 1);
    expect(c.state.doc.textContent, 'axb');
  });
  test('a converted paste can be restored to its text in one step', () async {
    final c = TiptapController(doc: docWith(text('ab')));
    addTearDown(c.dispose);
    var offers = 0;
    c.onPasteConverted = (_) => offers++;
    c.setSelection(const TextSelection(3));
    await c.paste(text: 'plain', onPasteText: (_) => null);
    expect(offers, 0);
    await c.paste(text: '# Title', onPasteText: (_) => heading);
    expect(offers, 1);
    expect(c.state.doc.childCount, greaterThan(1));
    c.restorePastedText();
    expect(c.state.doc.textContent, 'abplain# Title');
    c.exec('undo');
    expect(c.state.doc.textContent, 'abplain');
  });
  test(
    'external rich text can drop its formatting, copied text cannot',
    () async {
      final bold = schema.node(
        'paragraph',
        content: [
          schema.node('text', text: 'bold', marks: [schema.mark('bold')]),
        ],
      );
      final c = TiptapController(doc: docWith(bold));
      addTearDown(c.dispose);
      final offers = <TiptapPasteConversion>[];
      c.onPasteConverted = offers.add;
      var copiedText = '', copiedHtml = '';
      c.setSelection(const TextSelection(1, 5));
      await c.copy(
        write: (text, html) async {
          copiedText = text;
          copiedHtml = html;
        },
      );
      await c.pasteHtml(copiedHtml, text: copiedText);
      expect(offers, isEmpty);

      c.replaceDocument(docWith(schema.node('paragraph')));
      await c.pasteHtml('<p><strong>web</strong></p>', text: 'web');
      expect(offers, [TiptapPasteConversion.richText]);
      expect(c.state.doc.child(0).content.first.marks.single.type, 'bold');
      c.restorePastedText();
      expect(c.state.doc.textContent, 'web');
      expect(c.state.doc.child(0).content.first.marks, isEmpty);

      await c.pasteHtml('<p>plain</p>', text: 'plain');
      expect(offers, hasLength(1));
    },
  );
  test('plain paste keeps the literal text', () async {
    final c = TiptapController(doc: docWith(text('ab')));
    addTearDown(c.dispose);
    c.setSelection(const TextSelection(1, 3));
    await c.pastePlainText(text: 'https://a.b');
    expect(c.state.doc.textContent, 'https://a.b');
    expect(c.state.doc.child(0).content.first.marks, isEmpty);
    c.setSelection(TextSelection(c.state.doc.content.size - 1));
    await c.pastePlainText(text: ' **x**');
    expect(c.state.doc.textContent, 'https://a.b **x**');
  });
  test('HTML copy/cut retains internal slices and external HTML replaces formatting', () async {
    final c = TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              schema.node('text', text: 'bold', marks: [schema.mark('bold')]),
            ],
          ),
        ],
      ),
    );
    addTearDown(c.dispose);
    c.setSelection(const TextSelection(1, 5));
    var text = '', html = '';
    await c.copy(
      write: (plain, rich) async {
        text = plain;
        html = rich;
      },
    );
    expect(text, 'bold');
    expect(html, contains('>bold</strong>'));
    expect(html, contains('data-pm-slice="0 0 []"'));
    c.replaceDocument(schema.node('doc', content: [schema.node('paragraph')]));
    await c.pasteHtml(html, text: text);
    expect(c.state.doc.content.first.content.first.marks.single.type, 'bold');
    c.replaceDocument(schema.node('doc', content: [schema.node('paragraph')]));
    await c.pasteHtml('<p>bold</p>', text: text);
    expect(c.state.doc.content.first.content.first.marks, isEmpty);
    c.setSelection(const TextSelection(1, 5));
    await c.copy(
      cut: true,
      write: (_, rich) async {
        html = rich;
      },
    );
    expect(c.state.doc.textContent, '');
  });
  test(
    'HTML in code is plain text; image atoms copy even with no plain text',
    () async {
      final c = TiptapController(
        doc: schema.node(
          'doc',
          content: [
            schema.node('image', attrs: {'src': 'https://example.com/a.png'}),
            schema.node('paragraph'),
          ],
        ),
      );
      addTearDown(c.dispose);
      c.setSelection(NodeSelection(c.state.doc, 0));
      var html = '';
      await c.copy(
        write: (text, rich) async {
          expect(text, isEmpty);
          html = rich;
        },
      );
      expect(html, contains('<img'));
      c.replaceDocument(
        schema.node('doc', content: [schema.node('codeBlock')]),
      );
      await c.pasteHtml('<p><strong>bold</strong></p>', text: 'bold');
      expect(c.state.doc.content.first.textContent, 'bold');
      expect(c.state.doc.content.first.content.first.marks, isEmpty);
    },
  );
}
