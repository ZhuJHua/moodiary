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
  mood: 0.5,
  weather: const [],
  imageName: imageName,
  audioName: audioName,
  videoName: videoName,
  tags: const [],
  position: const [],
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
      final c = DiaryContent.of(_diary(content: doc, type: DiaryType.tiptap));
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
      final c = DiaryContent.of(_diary(content: md, type: DiaryType.markdown));
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
      final c = DiaryContent.of(
        _diary(content: asJson, type: DiaryType.markdown),
      );
      expect(c.plainText, MarkdownConverter.convert(asJson));
      expect(c.links, isEmpty);
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
      final c = DiaryContent.of(
        _diary(content: delta, type: DiaryType.richText),
      );
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
      final c = DiaryContent.of(
        _diary(content: delta, type: DiaryType.richText),
      );
      expect(c.media.images, ['image-1.webp']);
      expect(c.media.videos, ['video-1.mp4']);
      expect(c.media.audios, ['audio-1.m4a']);
    });

    test('非法 Delta：plainText 回退原文，media 回退已存字段（不清空引用）', () {
      final c = DiaryContent.of(
        _diary(
          content: '这不是 Delta',
          type: DiaryType.richText,
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
          type: DiaryType.richText,
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
      mood: 0.5,
      weather: const [],
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      position: const [],
      type: 'text',
    );
    expect(DiaryContent.of(diary).plainText, '');
  });
}
