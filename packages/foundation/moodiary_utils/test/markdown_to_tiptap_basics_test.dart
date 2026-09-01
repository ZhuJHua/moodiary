import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Map<String, dynamic> doc(String md) =>
    jsonDecode(MarkdownToTiptap.convert(md)!) as Map<String, dynamic>;

List<dynamic> content(String md) => doc(md)['content'] as List<dynamic>;

void main() {
  group('MarkdownToTiptap — 基础', () {
    test('doc 结构 + 段落', () {
      final d = doc('hello world');
      expect(d['type'], 'doc');
      expect(d['content'][0], {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': 'hello world'},
        ],
      });
    });

    test('空串 → 单个空段落', () {
      expect(content('')[0], {'type': 'paragraph'});
    });

    test('heading 带 level', () {
      final c = content('## 标题');
      expect(c[0]['type'], 'heading');
      expect(c[0]['attrs'], {'level': 2});
      expect(c[0]['content'][0]['text'], '标题');
    });

    test('行内 bold/italic/strike/code/link', () {
      final nodes =
          (content('**b** _i_ ~~s~~ `c` [t](https://e.com)')[0]['content']
              as List);
      Map<String, dynamic> byText(String t) =>
          nodes.firstWhere((n) => n['text'] == t) as Map<String, dynamic>;
      expect((byText('b')['marks'] as List).first['type'], 'bold');
      expect((byText('i')['marks'] as List).first['type'], 'italic');
      expect((byText('s')['marks'] as List).first['type'], 'strike');
      expect((byText('c')['marks'] as List).first['type'], 'code');
      expect((byText('t')['marks'] as List).first, {
        'type': 'link',
        'attrs': {'href': 'https://e.com'},
      });
    });
  });

  group('MarkdownToTiptap — 块', () {
    test('无序列表', () {
      final c = content('- a\n- b');
      expect(c[0]['type'], 'bulletList');
      final items = c[0]['content'] as List;
      expect(items.length, 2);
      expect(items[0]['type'], 'listItem');
      expect(items[0]['content'][0]['type'], 'paragraph');
    });

    test('有序列表带 start', () {
      final c = content('3. x\n4. y');
      expect(c[0]['type'], 'orderedList');
      expect(c[0]['attrs'], {'start': 3});
    });

    test('任务列表 → taskList + taskItem.checked', () {
      final c = content('- [x] done\n- [ ] todo');
      expect(c[0]['type'], 'taskList');
      final items = c[0]['content'] as List;
      expect(items[0]['type'], 'taskItem');
      expect(items[0]['attrs'], {'checked': true});
      expect(items[1]['attrs'], {'checked': false});
      expect(items[0]['content'][0]['content'][0]['text'], 'done');
    });

    test('引用', () {
      final c = content('> quote');
      expect(c[0]['type'], 'blockquote');
      expect(c[0]['content'][0]['type'], 'paragraph');
    });

    test('代码块带语言', () {
      final c = content('```dart\nvar x = 1;\n```');
      expect(c[0]['type'], 'codeBlock');
      expect(c[0]['attrs'], {'language': 'dart'});
      expect(c[0]['content'][0]['text'], 'var x = 1;');
    });

    test('分隔线', () {
      final c = content('a\n\n---\n\nb');
      expect(c.any((n) => n['type'] == 'horizontalRule'), isTrue);
    });

    test('表格 → table / tableRow / tableHeader / tableCell', () {
      final c = content('| A | B |\n|---|---|\n| 1 | 2 |');
      expect(c[0]['type'], 'table');
      final rows = c[0]['content'] as List;
      expect(rows[0]['content'][0]['type'], 'tableHeader');
      expect(rows[1]['content'][0]['type'], 'tableCell');
      expect(rows[0]['content'][0]['content'][0]['type'], 'paragraph');
    });
  });

  group('MarkdownToTiptap — 媒体', () {
    test('图片 / 音频 / 视频按文件名前缀分流为一等节点', () {
      expect(content('![](image-1.jpg)')[0], {
        'type': 'image',
        'attrs': {'src': 'image-1.jpg'},
      });
      expect(content('![](audio-1.m4a)')[0], {
        'type': 'audio',
        'attrs': {'filename': 'audio-1.m4a'},
      });
      expect(content('![](video-1.mp4)')[0], {
        'type': 'video',
        'attrs': {'filename': 'video-1.mp4'},
      });
    });

    test('图片带 alt 保留', () {
      expect(content('![cover](image-1.jpg)')[0], {
        'type': 'image',
        'attrs': {'src': 'image-1.jpg', 'alt': 'cover'},
      });
    });

    test('文字 + 图片混排：拆成段落 + image 块', () {
      final c = content('text ![](image-1.jpg)');
      expect(c.any((n) => n['type'] == 'paragraph'), isTrue);
      expect(c.any((n) => n['type'] == 'image'), isTrue);
    });
  });
}
