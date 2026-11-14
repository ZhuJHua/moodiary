import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ft.TiptapController controller;
  final largeText = 'x' * (1024 * 1024 + 1);
  setUp(() => controller = ft.TiptapController());
  tearDown(() => controller.dispose());

  List<ft.Node> linked() => [
    for (final row in controller.state.doc.rows())
      for (final node in row.node.content)
        if (node.marks.any((mark) => mark.type == 'link')) node,
  ];

  String href(ft.Node node) =>
      node.marks.firstWhere((mark) => mark.type == 'link').attrs['href']
          as String;

  for (final useHtml in [true, false]) {
    test(
      '${useHtml ? 'HTML' : 'slice'} paste links only inserted text',
      () async {
        final schema = ft.Schema.standard();
        controller.replaceDocument(
          schema.node(
            'doc',
            content: [
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'outside.com ')],
              ),
            ],
          ),
        );
        controller.setSelection(const ft.TextSelection(13));
        controller.exec('insertText', {'text': '! '});
        final before = controller.state.doc;
        const html = '<p>visit example.com</p>';
        if (useHtml) {
          await controller.pasteHtml(html);
        } else {
          controller.exec('pasteSlice', {
            'slice': ft.TiptapHtmlCodec(schema).parseSlice(html),
          });
        }
        expect(
          controller.state.doc.textContent,
          'outside.com ! visit example.com',
        );
        expect(linked().map((node) => node.text), ['example.com']);
        expect(href(linked().single), 'http://example.com');
        controller.exec('undo');
        expect(controller.state.doc.eq(before), true);
        controller.exec('undo');
        expect(controller.state.doc.textContent, 'outside.com ');
        expect(controller.state.history.canUndo, false);
      },
    );
  }

  test('HTML paste preserves explicit hrefs and excludes code', () async {
    await controller.pasteHtml(
      '<p><a href="https://custom.test/path">example.com</a> '
      '<code>code.com</code> <strong>bare.com</strong></p>'
      '<pre><code>block.com</code></pre>',
      text: 'example.com code.com bare.com\nblock.com',
    );
    expect(linked().map((node) => node.text), ['example.com', 'bare.com']);
    expect(linked().map(href), ['https://custom.test/path', 'http://bare.com']);
    final paragraph = controller.state.doc.child(0);
    final code = paragraph.content.singleWhere(
      (node) => node.text == 'code.com',
    );
    expect(code.marks.map((mark) => mark.type), ['code']);
    expect(linked().last.marks.map((mark) => mark.type), contains('bold'));
    final block = controller.state.doc.blocks.singleWhere(
      (node) => node.type == 'codeBlock',
    );
    expect(block.textContent, 'block.com');
    expect(block.child(0).marks, isEmpty);
    controller.exec('undo');
    expect(controller.state.doc.textContent, '');
    expect(controller.state.history.canUndo, false);
  });

  for (final useHtml in [true, false]) {
    test(
      'internal ${useHtml ? 'HTML' : 'text'} copy skips link paste rules',
      () async {
        final schema = controller.state.doc.schema;
        controller.insertPlainText('visit example.com');
        controller.setSelection(const ft.TextSelection(1, 18));
        late String copiedText, copiedHtml;
        await controller.copy(
          write: (text, html) async {
            copiedText = text;
            copiedHtml = html;
          },
        );
        controller.replaceDocument(
          schema.node('doc', content: [schema.node('paragraph')]),
        );
        if (useHtml) {
          await controller.pasteHtml(copiedHtml, text: copiedText);
        } else {
          await controller.paste(text: copiedText);
        }
        expect(controller.state.doc.textContent, 'visit example.com');
        expect(linked(), isEmpty);
        controller.exec('undo');
        expect(controller.state.doc.textContent, '');
        expect(controller.state.history.canUndo, false);
      },
    );
  }

  for (final convert in [false, true]) {
    test(
      'ProseMirror HTML skips link paste rules (conversion: $convert)',
      () async {
        const html = '<p data-pm-slice="1 1 []">visit example.com</p>';
        await controller.pasteHtml(
          html,
          text: 'visit example.com',
          onPasteText: convert
              ? (_) =>
                    ft.TiptapHtmlCodec(controller.state.doc.schema)
                        .parse(html)
                        .toJson()
              : null,
        );
        expect(controller.state.doc.textContent, 'visit example.com');
        expect(linked(), isEmpty);
      },
    );
  }

  test(
    'plain clipboard paste above 1M still runs conversion and inserts',
    () async {
      final schema = ft.Schema.standard();
      var converted = false;
      await controller.paste(
        text: largeText,
        onPasteText: (_) {
          converted = true;
          return schema
              .node(
                'doc',
                content: [
                  schema.node(
                    'codeBlock',
                    content: [schema.node('text', text: largeText)],
                  ),
                ],
              )
              .toJson();
        },
      );
      expect(converted, true);
      expect(controller.state.doc.textContent.length, largeText.length);
      controller.exec('undo');
      expect(controller.state.doc.textContent, '');
    },
  );

  test('literal clipboard paste above 1M inserts all text', () async {
    final schema = ft.Schema.standard();
    controller.replaceDocument(
      schema.node('doc', content: [schema.node('codeBlock')]),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => {'text': largeText},
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await controller.pastePlainText();
    expect(controller.state.doc.textContent.length, largeText.length);
  });

  test('HTML clipboard paste above 1M keeps its rich representation', () async {
    await controller.pasteHtml(
      '<!--$largeText--><p><strong>safe</strong></p>',
      text: 'fallback',
    );
    expect(controller.state.doc.textContent, 'safe');
    expect(controller.state.doc.child(0).child(0).marks.first.type, 'bold');
    controller.exec('undo');
    expect(controller.state.doc.textContent, '');
  });

  test('HTML clipboard paste in code keeps alternate text above 1M', () async {
    final schema = ft.Schema.standard();
    controller.replaceDocument(
      schema.node('doc', content: [schema.node('codeBlock')]),
    );
    await controller.pasteHtml('<p><strong>safe</strong></p>', text: largeText);
    expect(controller.state.doc.child(0).textContent.length, largeText.length);
  });

  for (final cut in [false, true]) {
    test(
      'single cell ${cut ? 'cut' : 'copy'} and paste preserve formatting and neighbors',
      () async {
        final schema = ft.Schema.standard();
        controller.replaceDocument(
          ft.TiptapHtmlCodec(schema).parse(
            '<table><tr><td><p>keep</p></td><td><p><strong>selected</strong></p></td>'
            '<td><p>target</p></td></tr></table><p></p>',
          ),
        );
        final before = controller.state.doc;
        final source = ft.TableMap.get(before.child(0)).map[1] + 1;
        controller.setSelection(ft.TextSelection(source + 2, source + 10));
        late String copiedText, copiedHtml;
        await controller.copy(
          cut: cut,
          write: (text, html) async {
            copiedText = text;
            copiedHtml = html;
          },
        );
        expect(copiedText, 'selected');
        expect(
          copiedHtml,
          matches(RegExp(r'<strong(?: [^>]*)?>selected</strong>')),
        );
        final current = controller.state.doc;
        final target = ft.TableMap.get(current.child(0)).map[2] + 1;
        controller.setSelection(ft.TextSelection(target + 2, target + 8));
        await controller.pasteHtml(copiedHtml, text: copiedText);
        final cells = controller.state.doc.child(0).child(0).content.toList();
        expect(cells.map((cell) => cell.textContent), [
          'keep',
          cut ? '' : 'selected',
          'selected',
        ]);
        expect(cells[2].child(0).child(0).marks.single.type, 'bold');
        expect(controller.cellPosition, target);
        controller.exec('undo');
        expect(controller.state.doc.toJson(), current.toJson());
        if (cut) {
          controller.exec('undo');
          expect(controller.state.doc.toJson(), before.toJson());
          expect(
            controller.state.selection,
            ft.TextSelection(source + 2, source + 10),
          );
        }
      },
    );
  }

  test('copied internal HTML and slice above 1M preserve formatting', () async {
    final schema = ft.Schema.standard();
    controller.replaceDocument(
      schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              schema.node(
                'text',
                text: largeText,
                marks: [schema.mark('bold')],
              ),
            ],
          ),
        ],
      ),
    );
    controller.setSelection(ft.TextSelection(1, largeText.length + 1));
    late String copiedText, copiedHtml;
    await controller.copy(
      write: (text, html) async {
        copiedText = text;
        copiedHtml = html;
      },
    );
    controller.replaceDocument(
      schema.node('doc', content: [schema.node('paragraph')]),
    );
    await controller.pasteHtml(copiedHtml, text: copiedText);
    expect(controller.state.doc.textContent.length, largeText.length);
    expect(controller.state.doc.child(0).child(0).marks.first.type, 'bold');
    controller.exec('undo');
    expect(controller.state.doc.textContent, '');
  });
}
