import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

String _doc(List<Map<String, dynamic>> content) =>
    jsonEncode({'type': 'doc', 'content': content});

Map<String, dynamic> _p(List<Map<String, dynamic>> inline) => {
  'type': 'paragraph',
  'content': inline,
};

Map<String, dynamic> _text(String t) => {'type': 'text', 'text': t};

void main() {
  group('TiptapContent — TipTap 文档', () {
    test('plainText 按块补换行、收敛 3+ 空行、首尾 trim', () {
      final c = TiptapContent.parse(
        _doc([
          _p([_text('第一段')]),
          {'type': 'horizontalRule'},
          {'type': 'horizontalRule'},
          _p([_text('第二段')]),
        ]),
      );
      expect(c.isDoc, isTrue);
      expect(c.plainText, '第一段\n\n第二段');
    });

    test('plainText 计入双链标签', () {
      final c = TiptapContent.parse(
        _doc([
          _p([
            _text('看这篇'),
            {
              'type': 'diaryLink',
              'attrs': {'id': 'a1', 'label': '去年今日'},
            },
          ]),
        ]),
      );
      expect(c.plainText, '看这篇去年今日');
    });

    test('media 按节点类型分流、去重且保序', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': 'image-b.webp'},
          },
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-1.m4a'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-a.webp'},
          },
          {
            'type': 'video',
            'attrs': {'filename': 'video-1.mp4'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-b.webp'},
          },
        ]),
      );
      expect(c.media.images, ['image-b.webp', 'image-a.webp']);
      expect(c.media.audios, ['audio-1.m4a']);
      expect(c.media.videos, ['video-1.mp4']);
    });

    test('media 忽略空串与缺失 attrs，不产生幻影引用', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': ''},
          },
          {'type': 'image'},
          {
            'type': 'audio',
            'attrs': {'filename': null},
          },
        ]),
      );
      expect(c.media.images, isEmpty);
      expect(c.media.audios, isEmpty);
      expect(c.media.videos, isEmpty);
    });

    test('links 去重保序，忽略空 id', () {
      final c = TiptapContent.parse(
        _doc([
          _p([
            {
              'type': 'diaryLink',
              'attrs': {'id': 'b'},
            },
            {
              'type': 'diaryLink',
              'attrs': {'id': 'a'},
            },
            {
              'type': 'diaryLink',
              'attrs': {'id': 'b'},
            },
            {
              'type': 'diaryLink',
              'attrs': {'id': ''},
            },
          ]),
        ]),
      );
      expect(c.links, ['b', 'a']);
    });

    test('headings 保文档序、级别钳制到 1-6、收集内联文本', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'heading',
            'attrs': {'level': 9},
            'content': [_text('过大')],
          },
          {
            'type': 'heading',
            'attrs': {'level': 0},
            'content': [_text('过小')],
          },
          {
            'type': 'heading',
            'content': [_text('缺级别')],
          },
          {
            'type': 'heading',
            'attrs': {'level': 2},
            'content': [
              _text('带链接 '),
              {
                'type': 'diaryLink',
                'attrs': {'id': 'x', 'label': '标签'},
              },
            ],
          },
        ]),
      );
      expect(c.headings.map((h) => h.level).toList(), [6, 1, 1, 2]);
      expect(c.headings.map((h) => h.text).toList(), [
        '过大',
        '过小',
        '缺级别',
        '带链接 标签',
      ]);
    });

    test('多次读取同一派生结果一致（惰性缓存不改变语义）', () {
      final c = TiptapContent.parse(
        _doc([
          _p([_text('稳定')]),
          {
            'type': 'image',
            'attrs': {'src': 'image-1.webp'},
          },
        ]),
      );
      expect(c.plainText, c.plainText);
      expect(c.media.images, c.media.images);
      expect(identical(c.media, c.media), isTrue);
    });
  });

  group('TiptapContent — 非 TipTap 内容的回退', () {
    test('旧 markdown：plainText 走 MarkdownConverter，媒体走正则前缀分流', () {
      const md = '# 标题\n\n正文 ![](image-1.webp) ![](audio-1.m4a) ![](video-1.mp4)';
      final c = TiptapContent.parse(md);
      expect(c.isDoc, isFalse);
      expect(c.plainText, MarkdownConverter.convert(md));
      expect(c.media.images, ['image-1.webp']);
      expect(c.media.audios, ['audio-1.m4a']);
      expect(c.media.videos, ['video-1.mp4']);
      expect(c.links, isEmpty);
      expect(c.headings, isEmpty);
    });

    test('以 { 开头但不是合法 JSON → 回退，不抛出', () {
      final c = TiptapContent.parse('{不是 JSON');
      expect(c.isDoc, isFalse);
      expect(c.plainText, isNotNull);
    });

    test('合法 JSON 但 type 不是 doc → 回退', () {
      final c = TiptapContent.parse(jsonEncode({'type': 'paragraph'}));
      expect(c.isDoc, isFalse);
    });

    test('空串安全', () {
      final c = TiptapContent.parse('');
      expect(c.isDoc, isFalse);
      expect(c.plainText, '');
      expect(c.media.images, isEmpty);
      expect(c.links, isEmpty);
    });
  });
}
