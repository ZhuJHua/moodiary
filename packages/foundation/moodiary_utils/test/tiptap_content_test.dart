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
      const md =
          '# 标题\n\n正文 ![](image-1.webp) ![](audio-1.m4a) ![](video-1.mp4)';
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

  group('TiptapContent — 外链不入媒体引用', () {
    test('http/https/data 开头的 image src 不进 images', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': 'https://example.com/a.png'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'data:image/png;base64,xxxx'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-local.png'},
          },
        ]),
      );
      expect(c.media.images, ['image-local.png']);
    });
  });

  group('TiptapContent.wrapPlainText', () {
    test('逐行成段、文字原样保留', () {
      final c = TiptapContent.parse(
        TiptapContent.wrapPlainText('第一行\n第二行 "带引号" & <符号>'),
      );
      expect(c.isDoc, isTrue);
      expect(c.plainText, '第一行\n第二行 "带引号" & <符号>');
    });

    test('空文本给单个空段落，仍是合法文档', () {
      final c = TiptapContent.parse(TiptapContent.wrapPlainText(''));
      expect(c.isDoc, isTrue);
      expect(c.plainText, '');
    });
  });

  group('TiptapContent.ensureMedia — 媒体守恒', () {
    test('缺失的媒体以一等节点追加到文末，字段重算只增不减', () {
      final doc = _doc([
        _p([_text('正文')]),
        {
          'type': 'image',
          'attrs': {'src': 'image-kept.png'},
        },
      ]);
      final ensured = TiptapContent.ensureMedia(
        doc,
        images: ['image-kept.png', 'image-lost.png'],
        audios: ['audio-lost.m4a'],
        videos: ['video-lost.mp4'],
      );
      final media = TiptapContent.parse(ensured).media;
      expect(media.images, ['image-kept.png', 'image-lost.png']);
      expect(media.audios, ['audio-lost.m4a']);
      expect(media.videos, ['video-lost.mp4']);
    });

    test('全部在场时原样返回（字节不变）', () {
      final doc = _doc([
        {
          'type': 'image',
          'attrs': {'src': 'image-a.png'},
        },
      ]);
      expect(
        TiptapContent.ensureMedia(doc, images: ['image-a.png'], audios: [], videos: []),
        same(doc),
      );
    });

    test('整篇被判成代码块（缩进日记）时图片引用救得回来', () {
      // MarkdownToTiptap 对全文 4 空格缩进的产物：单个 codeBlock，图片成了字面文本。
      final doc = _doc([
        {
          'type': 'codeBlock',
          'content': [_text('今天天气很好。\n![](image-aaa.png)')],
        },
      ]);
      final media = TiptapContent.parse(
        TiptapContent.ensureMedia(doc, images: ['image-aaa.png'], audios: [], videos: []),
      ).media;
      expect(media.images, ['image-aaa.png']);
    });

    test('非 doc 输入原样返回，不抛出', () {
      expect(
        TiptapContent.ensureMedia('not a doc', images: ['image-a.png'], audios: [], videos: []),
        'not a doc',
      );
    });

    test('空串与重复名安全（去重、忽略空名）', () {
      final doc = _doc([_p([_text('x')])]);
      final media = TiptapContent.parse(
        TiptapContent.ensureMedia(
          doc,
          images: ['', 'image-a.png', 'image-a.png'],
          audios: [],
          videos: [],
        ),
      ).media;
      expect(media.images, ['image-a.png']);
    });

    test('外链不参与守恒：media 收集时排除，不会被反复判缺失追加', () {
      final doc = _doc([_p([_text('x')])]);
      expect(
        TiptapContent.ensureMedia(
          doc,
          images: ['https://example.com/a.png'],
          audios: [],
          videos: [],
        ),
        same(doc),
      );
    });
  });
}
