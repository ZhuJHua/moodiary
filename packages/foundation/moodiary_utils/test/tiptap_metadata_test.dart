import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  final fixtures = [
    TiptapContent.newDoc([]),
    TiptapContent.newDoc([
      {
        'type': 'heading',
        'attrs': {'level': 9},
        'content': [
          {'type': 'text', 'text': '  标题 👨‍👩‍👧‍👦 é  '},
          {
            'type': 'diaryLink',
            'attrs': {'id': 'id', 'label': ' 链接'},
          },
        ],
      },
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': '中文 日本語 한글\t\n 🇨🇳 👍🏽 é \ufdd0x\ufdd1'},
          {'type': 'hardBreak'},
          {
            'type': 'diaryLink',
            'attrs': {'id': 'fallback'},
          },
        ],
      },
      for (final type in ['image', 'video', 'audio', 'attachment'])
        {
          'type': type,
          'attrs': {'src': '$type-file', 'name': '媒体 $type'},
        },
      {'type': 'paragraph'},
    ]),
    {
      'type': 'doc',
      'content': [
        {
          'type': 'heading',
          'content': [
            {'type': 'text', 'text': 'legacy'},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-a.png'},
        },
      ],
    },
  ];

  for (var index = 0; index < fixtures.length; index++) {
    test('shared metadata matches independent computations ($index)', () {
      final raw = jsonEncode(fixtures[index]);
      final previous = TiptapContent.parse(raw);
      final text = previous.plainText;
      final decoded = TiptapContent.fromDocument(
        TiptapContent.parse(raw).document!,
      );
      final metadata = decoded.metadata(contentText: text);
      expect(metadata.plainText, same(text));
      expect(metadata.headings, previous.headings);
      expect(metadata.characterCount, TiptapContent.countCharacters(text));
      expect(metadata.contentTextCharacterCount, metadata.characterCount);
      expect(() => metadata.headings.clear(), throwsUnsupportedError);
      final stale = decoded.metadata(contentText: '旧 👨‍👩‍👧‍👦 \n');
      expect(stale.plainText, text);
      expect(stale.characterCount, metadata.characterCount);
      expect(stale.contentTextCharacterCount, 2);
    });
  }

  test(
    'protected and plain inputs retain separate rendered and stored values',
    () {
      for (final raw in ['# markdown\n**你好**', '{broken', '']) {
        final rendered = TiptapContent.parse(TiptapContent.wrapPlainText(raw));
        final source = TiptapContent.parse(raw);
        final result = source.metadata(
          contentText: 'saved',
          renderedContent: rendered,
        );
        expect(result.headings, source.headings);
        expect(result.plainText, rendered.plainText);
        expect(
          result.characterCount,
          TiptapContent.countCharacters(rendered.plainText),
        );
        expect(
          result.contentTextCharacterCount,
          TiptapContent.countCharacters('saved'),
        );
      }
    },
  );
}
