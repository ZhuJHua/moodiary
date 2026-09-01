import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Diary _diary({
  required String content,
  required DiaryType type,
  List<String> imageName = const [],
  List<String> videoName = const [],
  List<String> audioName = const [],
}) => Diary(
  id: 'd1',
  title: 't',
  content: content,
  contentText: '',
  time: DateTime(2026, 1, 1),
  lastModified: DateTime(2026, 1, 1),
  show: true,
  mood: .neutral,
  imageName: imageName,
  audioName: audioName,
  videoName: videoName,
  tags: const [],
  type: type.value,
);

void main() {
  group('DiaryContent — tiptap', () {
    final doc = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '今天很好'},
            {
              'type': 'diaryLink',
              'attrs': {'id': 'other', 'label': '旧日记'},
            },
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
      ],
    });

    test('三项派生与 TiptapContent 一致', () {
      final c = DiaryContent.of(_diary(content: doc, type: .tiptap));
      final direct = TiptapContent.parse(doc);
      expect(c.plainText, direct.plainText);
      expect(c.media.images, direct.media.images);
      expect(c.links, direct.links);
      expect(c.links, ['other']);
    });
  });

  group('DiaryContent — markdown', () {
    const md = '正文 ![](image-1.webp) ![](video-1.mp4) ![](audio-1.m4a)';

    test('plainText 走 markdown 转换，媒体按前缀分流，无双链', () {
      final c = DiaryContent.of(_diary(content: md, type: .markdown));
      expect(c.plainText, MarkdownConverter.convert(md));
      expect(c.media.images, ['image-1.webp']);
      expect(c.media.videos, ['video-1.mp4']);
      expect(c.media.audios, ['audio-1.m4a']);
      expect(c.links, isEmpty);
    });

    test('即使正文恰好是 TipTap JSON，markdown 类型也不按 doc 解析', () {
      final asJson = jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'x'},
            ],
          },
        ],
      });
      final c = DiaryContent.of(_diary(content: asJson, type: .markdown));
      expect(c.plainText, MarkdownConverter.convert(asJson));
      expect(c.links, isEmpty);
    });
  });

  group('DiaryContent — 媒体守恒（正则少认时不清空已有引用）', () {
    // 这四种手打 markdown 写法 `![](name)` 正则都认不出，但文件名仍在正文里。
    // 少认即清空 imageName → 媒体成孤儿 → 「清理无用文件」永久删除 + LWW 扩散。
    const cases = {
      'title 语法': '![](image-a.png "标题")',
      '尖括号': '![](<image-a.png>)',
      '引用式': '![alt][r]\n\n[r]: image-a.png',
      'alt 里带右括号': '![a]b]](image-a.png)',
    };
    for (final entry in cases.entries) {
      test('${entry.key}：保留已有引用', () {
        final d = _diary(
          content: entry.value,
          type: .markdown,
          imageName: const ['image-a.png'],
        );
        expect(DiaryContent.of(d).media.images, ['image-a.png']);
      });
    }

    test('正文里已经没有的引用不救（真删掉的该回收）', () {
      final d = _diary(
        content: '只剩文字了',
        type: .markdown,
        imageName: const ['image-gone.png'],
      );
      expect(DiaryContent.of(d).media.images, isEmpty);
    });

    test('正则认得出时不重复计入', () {
      final d = _diary(
        content: '![](image-a.png)',
        type: .markdown,
        imageName: const ['image-a.png'],
      );
      expect(DiaryContent.of(d).media.images, ['image-a.png']);
    });

    test('tiptap 正文解析不出 doc 时同样兜住', () {
      final d = _diary(
        content: '![](image-a.png "标题")',
        type: .tiptap,
        imageName: const ['image-a.png'],
      );
      expect(DiaryContent.of(d).media.images, ['image-a.png']);
    });
  });

  group('DiaryContent — richText（旧 Quill Delta）', () {
    test('plainText 拼接字符串 insert，保留行内换行、只裁尾部', () {
      final delta = jsonEncode([
        {'insert': '第一行\n'},
        {
          'insert': {'image': 'image-1.webp'},
        },
        {'insert': '第二行\n\n'},
      ]);
      final c = DiaryContent.of(_diary(content: delta, type: .richText));
      expect(c.plainText, '第一行\n第二行');
    });

    test('media 从 embed insert 抽取三类', () {
      final delta = jsonEncode([
        {
          'insert': {'image': 'image-1.webp'},
        },
        {
          'insert': {'video': 'video-1.mp4'},
        },
        {
          'insert': {'audio': 'audio-1.m4a'},
        },
      ]);
      final c = DiaryContent.of(_diary(content: delta, type: .richText));
      expect(c.media.images, ['image-1.webp']);
      expect(c.media.videos, ['video-1.mp4']);
      expect(c.media.audios, ['audio-1.m4a']);
    });

    test('非法 Delta：plainText 回退原文，media 回退已存字段（不清空引用）', () {
      final c = DiaryContent.of(
        _diary(
          content: '这不是 Delta',
          type: .richText,
          imageName: const ['image-keep.webp'],
          videoName: const ['video-keep.mp4'],
          audioName: const ['audio-keep.m4a'],
        ),
      );
      expect(c.plainText, '这不是 Delta');
      expect(c.media.images, ['image-keep.webp']);
      expect(c.media.videos, ['video-keep.mp4']);
      expect(c.media.audios, ['audio-keep.m4a']);
      expect(c.links, isEmpty);
    });

    test('合法但空的 Delta 不会误回退到已存字段', () {
      final c = DiaryContent.of(
        _diary(
          content: '[]',
          type: .richText,
          imageName: const ['image-stale.webp'],
        ),
      );
      expect(c.media.images, isEmpty);
    });
  });

  test('未知 type 按 richText 处理（DiaryType.fromValue 的兜底）', () {
    final diary = Diary(
      id: 'd2',
      title: 't',
      content: '[]',
      contentText: '',
      time: DateTime(2026, 1, 1),
      lastModified: DateTime(2026, 1, 1),
      show: true,
      mood: .neutral,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: 'text',
    );
    expect(DiaryContent.of(diary).plainText, '');
  });
}
