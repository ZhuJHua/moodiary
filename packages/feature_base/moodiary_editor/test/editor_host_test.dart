import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_native/moodiary_native.dart';

String _doc(String text) => jsonEncode({
  'type': 'doc',
  'attrs': {'v': 2},
  'content': [
    {
      'type': 'paragraph',
      'content': [
        if (text.isNotEmpty) {'type': 'text', 'text': text},
      ],
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MoodiaryEditorHost host({
    String text = 'abc',
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    final h = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _doc(text),
        readOnly: readOnly,
        onChanged: onChanged,
      ),
    );
    addTearDown(h.dispose);
    return h;
  }

  testWidgets('stored multiline titles open as one line without saving', (
    tester,
  ) async {
    final titles = <String>[];
    final h = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _doc('body'),
        initialTitle: 'Travel\nDay 1',
        onTitleChanged: titles.add,
      ),
    );
    addTearDown(h.dispose);
    expect(h.title.text, 'Travel Day 1');
    await h.swapDocument(
      content: _doc('other'),
      title: 'One\r\nTwo\u2028Three',
    );
    expect(h.title.text, 'One Two Three');
    await tester.pump(const Duration(seconds: 1));
    expect(titles, isEmpty);
    h.title.text = 'One Two Three!';
    expect(titles, ['One Two Three!']);
  });

  test('URI-only Android image content uses the Pigeon resolver', () async {
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.ImageTransferApi.readContentUri',
      ImageTransferApi.pigeonChannelCodec,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(channel, (message) async {
      expect(message, ['content://keyboard/photo']);
      return [
        Uint8List.fromList([1, 2, 3]),
      ];
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    final received = <String>[];
    final h = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _doc(''),
        onSaveImage: (data, name) async {
          received.add(data);
          return 'image-saved.png';
        },
      ),
    );
    addTearDown(h.dispose);
    await h.pasteImage(
      const KeyboardInsertedContent(
        mimeType: 'image/png',
        uri: 'content://keyboard/photo',
      ),
    );
    expect(received, ['data:image/png;base64,AQID']);
  });
  group('pasted Markdown detection', () {
    Iterable<String> types(String text) =>
        (parsePastedMarkdown(text)!['content'] as List).map(
          (node) => (node as Map)['type'] as String,
        );

    for (final text in [
      '普通一行字',
      '- 买菜',
      '1. 单行也可能是普通文字',
      '第一行\n第二行',
      '#没有空格',
      'a == b',
      '2*3*4',
      'https://a.b',
    ]) {
      test('keeps "$text" as text', () {
        expect(parsePastedMarkdown(text), isNull);
      });
    }
    test('parses lines that only have Markdown in one place', () {
      expect(types('# 标题'), ['heading']);
      expect(types('---'), ['horizontalRule']);
      expect(types('这是 **加粗**'), ['paragraph']);
      expect(types('[链接](https://a.b)'), ['paragraph']);
      expect(types('第一段\n\n---\n\n第二段'), [
        'paragraph',
        'horizontalRule',
        'paragraph',
      ]);
      expect(types('明天\n- 买菜'), ['paragraph', 'bulletList']);
    });
    test('parses a typical AI answer', () {
      expect(
        types(
          '### 概念\n\n正文 **重点**\n第二行\n\n---\n\n'
          '| 名称 | 说明 |\n| --- | --- |\n| A | B |\n\n'
          '```dart\nvoid main() {}\n```\n',
        ),
        ['heading', 'paragraph', 'horizontalRule', 'table', 'codeBlock'],
      );
      final paragraph =
          (parsePastedMarkdown('一 **二**\n三')!['content'] as List).single as Map;
      expect((paragraph['content'] as List).map((n) => n['type']), [
        'text',
        'text',
        'hardBreak',
        'text',
      ]);
    });
  });
  test('all EditorCommand values have a dispatch path', () async {
    for (final command in EditorCommand.values) {
      final h = host(text: '');
      await h.exec(command, {
        'level': 2,
        'name': 'image-test.png',
        'displayName': 'test',
        'href': 'https://example.com',
        'text': 'x',
        'percent': 50,
        'variant': 'dashed',
        'query': 'x',
      });
    }
  });
  test(
    'toolbar mapping includes marks, headings, lists, link and table context',
    () async {
      final h = host();
      h.editor.setSelection(const ft.TextSelection(1, 4));
      await h.exec(EditorCommand.toggleBold, null);
      expect(h.state.value.has(EditorMark.bold), isTrue);
      await h.exec(EditorCommand.setHeading, {'level': 2});
      expect(h.state.value.block, EditorBlock.heading2);
      await h.exec(EditorCommand.setHeading, {'level': 2});
      expect(h.state.value.block, EditorBlock.paragraph);
      await h.exec(EditorCommand.toggleBulletList, null);
      expect(h.state.value.list, EditorList.bullet);
      expect(h.state.value.canOutdent, isTrue);
      expect(h.state.value.selectedText, 'abc');
      expect(h.state.value.canUndo, isTrue);
      await h.exec(EditorCommand.setLink, {
        'href': 'https://example.com',
        'text': 'abc',
      });
      expect(h.state.value.link?.href, 'https://example.com');
      await h.exec(EditorCommand.insertTable, null);
      expect(h.state.value.inTable, isTrue);
    },
  );
  testWidgets(
    'autosave debounces, flush delivers first edit before completing, swap is silent',
    (tester) async {
      final events = <String>[],
          h = host(text: '', onChanged: (json) => events.add(json));
      h.editor.exec('insertText', {'text': 'first'});
      await tester.pump(const Duration(milliseconds: 299));
      expect(events, isEmpty);
      await h.flush();
      expect(events, hasLength(1));
      expect(events.single, contains('first'));
      h.editor.exec('insertText', {'text': ' second'});
      await h.swapDocument(content: _doc('new'), title: 'new title');
      expect(events, hasLength(2));
      expect(events.last, contains('second'));
      await tester.pump(const Duration(seconds: 1));
      expect(events, hasLength(2));
      expect(h.editor.state.doc.textContent, 'new');
      expect(h.title.text, 'new title');
      expect(h.state.value.canUndo, isFalse);
      h.editor.exec('insertText', {'text': 'X'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(events, hasLength(3));
    },
  );
  test(
    'hold/restore selection applies a sheet command to the saved range',
    () async {
      final h = host();
      h.editor.setSelection(const ft.TextSelection(1, 3));
      await h.holdSelection();
      h.editor.setSelection(const ft.TextSelection(4));
      await h.exec(EditorCommand.toggleItalic, null);
      expect(h.editor.state.doc.child(0).child(0).text, 'ab');
      expect(h.editor.state.doc.child(0).child(0).marks.single.type, 'italic');
    },
  );
  for (final content in [
    jsonEncode({
      'type': 'doc',
      'attrs': {'v': 3},
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'future'},
          ],
        },
      ],
    }),
    '{"type":"doc","content":[',
    jsonEncode({
      'type': 'doc',
      'content': [
        {'type': 'unknown', 'content': []},
      ],
    }),
    jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'bulletList',
          'content': [
            {
              'type': 'listItem',
              'content': [
                {'type': 'text', 'text': 'loose'},
              ],
            },
          ],
        },
      ],
    }),
  ]) {
    test(
      'broken or newer schema is read-only and never saved: $content',
      () async {
        final saved = <String>[],
            h = MoodiaryEditorHost(
              MoodiaryEditor(initialContent: content, onChanged: saved.add),
            );
        addTearDown(h.dispose);
        expect(h.readOnly, isTrue);
        expect(h.state.value.contentError, isTrue);
        final before = h.editor.json;
        for (final command in [
          EditorCommand.toggleBold,
          EditorCommand.insertImage,
          EditorCommand.undo,
          EditorCommand.replaceAll,
        ]) {
          await h.exec(command, {'name': 'image-test.png', 'text': 'bad'});
        }
        await h.flush();
        expect(h.editor.json, before);
        expect(saved, isEmpty);
        h.update(MoodiaryEditor(initialContent: content, readOnly: false));
        expect(h.readOnly, isTrue);
        await h.swapDocument(content: _doc('valid'), title: '');
        expect(h.readOnly, isFalse);
        expect(h.state.value.contentError, isFalse);
      },
    );
  }
  test(
    'read-only permits search and previews while blocking mutations',
    () async {
      final h = host(text: 'abc abc', readOnly: true), before = h.editor.json;
      await h.exec(EditorCommand.search, {'query': 'abc'});
      expect(h.search.value?.total, 2);
      await h.exec(EditorCommand.searchNext, null);
      expect(h.search.value?.current, 2);
      await h.exec(EditorCommand.replaceAll, {'text': 'bad'});
      await h.exec(EditorCommand.toggleBold, null);
      expect(h.editor.json, before);
    },
  );
  for (final nextType in ['none', 'empty paragraph', 'paragraph', 'heading']) {
    test(
      'exitCode preserves the document and caret with $nextType after code',
      () async {
        final schema = ft.Schema.standard();
        final code = schema.node(
          'codeBlock',
          content: [schema.node('text', text: 'code')],
        );
        final next = switch (nextType) {
          'none' => null,
          'empty paragraph' => schema.node('paragraph'),
          'paragraph' => schema.node(
            'paragraph',
            content: [schema.node('text', text: 'next')],
          ),
          _ => schema.node(
            'heading',
            attrs: {'level': 2},
            content: [schema.node('text', text: 'next')],
          ),
        };
        final document = schema.node('doc', content: [code, ?next]);
        final h = host(text: '');
        h.editor.replaceDocument(document);
        h.editor.setSelection(const ft.TextSelection(3));
        await h.exec(EditorCommand.exitCode, null);
        final expected = schema.node(
          'doc',
          content: [
            code,
            if (nextType != 'empty paragraph') schema.node('paragraph'),
            ?next,
          ],
        );
        expect(h.editor.state.doc.toJson(), expected.toJson());
        expect(h.editor.state.selection, ft.TextSelection(code.nodeSize + 1));
      },
    );
  }
  test('media args, ephemeral width preview, hr update and exitCode', () async {
    final h = host(text: '');
    await h.exec(EditorCommand.insertImage, {
      'name': 'image-test.png',
      'displayName': 'Photo',
    });
    final image = h.editor.state.doc.child(0);
    h.editor.setSelection(ft.NodeSelection(h.editor.state.doc, 0));
    final before = h.editor.json;
    await h.exec(EditorCommand.previewMediaWidth, {'percent': 50});
    expect(h.editor.json, before);
    await h.exec(EditorCommand.setMediaWidth, {'percent': 50});
    expect(h.editor.state.doc.child(0).attrs['widthPercent'], 50);
    expect(image.attrs['name'], 'Photo');
    await h.exec(EditorCommand.setMediaName, {'name': 'renamed'});
    expect(h.state.value.node?.attrs['name'], 'renamed');
    await h.exec(EditorCommand.insertHorizontalRule, {'variant': 'double'});
    expect(
      h.editor.state.doc.content.any((n) => n.type == 'horizontalRule'),
      isTrue,
    );
    final schema = ft.Schema.standard();
    h.editor.replaceDocument(
      schema.node(
        'doc',
        content: [schema.node('codeBlock'), schema.node('paragraph')],
      ),
    );
    await h.exec(EditorCommand.exitCode, null);
    expect(h.editor.state.doc.childCount, 2);
  });
  test(
    'search, wraparound, CJK replacement and undo use the shared API',
    () async {
      final h = host(text: '中文 中文');
      await h.exec(EditorCommand.search, {'query': '中文'});
      expect(h.search.value?.current, 1);
      await h.exec(EditorCommand.searchPrev, null);
      expect(h.search.value?.current, 2);
      await h.exec(EditorCommand.replaceAll, {'text': '字'});
      expect(h.editor.state.doc.textContent, '字 字');
      await h.exec(EditorCommand.undo, null);
      expect(h.editor.state.doc.textContent, '中文 中文');
      await h.exec(EditorCommand.clearSearch, null);
      expect(h.search.value, isNull);
    },
  );
  test(
    'link text joins adjacent differently marked runs without inserting spaces',
    () async {
      final h = host();
      final schema = ft.Schema.standard(),
          link = schema.mark('link', {'href': 'https://example.com'});
      h.editor.replaceDocument(
        schema.node(
          'doc',
          content: [
            schema.node(
              'paragraph',
              content: [
                schema.node(
                  'text',
                  text: 'bo',
                  marks: [link, schema.mark('bold')],
                ),
                schema.node('text', text: 'ld', marks: [link]),
              ],
            ),
          ],
        ),
      );
      expect(h.state.value.link?.text, 'bold');
    },
  );
  test('stale pasted image cannot enter a swapped document', () async {
    final saved = Completer<String?>(),
        h = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: _doc(''),
            onSaveImage: (_, _) => saved.future,
          ),
        );
    addTearDown(h.dispose);
    final pending = h.pasteImage(
      TransferredImage(
        bytes: Uint8List.fromList([1, 2]),
        mime: 'image/png',
        name: 'image.png',
      ),
    );
    await h.swapDocument(content: _doc('other'), title: '');
    saved.complete('image-test.png');
    await pending;
    expect(h.editor.state.doc.childCount, 1);
    expect(h.editor.state.doc.textContent, 'other');
  });
}
