import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// 由 op 列表转换并解析回 doc map。
Map<String, dynamic> doc(List<Map<String, dynamic>> ops) =>
    jsonDecode(QuillDeltaToTiptap.convert(jsonEncode(ops))!) as Map<String, dynamic>;

List<dynamic> content(List<Map<String, dynamic>> ops) =>
    doc(ops)['content'] as List<dynamic>;

void main() {
  group('QuillDeltaToTiptap — 基础', () {
    test('doc 结构 + 普通段落', () {
      final d = doc([
        {'insert': 'hello\n'},
      ]);
      expect(d['type'], 'doc');
      expect(d['content'], [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        },
      ]);
    });

    test('解析失败 / 非数组返回 null', () {
      expect(QuillDeltaToTiptap.convert('not json'), isNull);
      expect(QuillDeltaToTiptap.convert('{"a":1}'), isNull);
    });

    test('空 Delta → 单个空段落', () {
      expect(content([
        {'insert': '\n'},
      ]), [
        {'type': 'paragraph'},
      ]);
    });

    test('行内标记 bold/italic/strike/code/link', () {
      final c = content([
        {'insert': 'a'},
        {
          'insert': 'b',
          'attributes': {'bold': true, 'italic': true},
        },
        {'insert': '\n'},
      ]);
      final marks = (c[0]['content'][1]['marks'] as List).map((m) => m['type']).toList();
      expect(marks, containsAll(['bold', 'italic']));

      final link = content([
        {
          'insert': 't',
          'attributes': {'link': 'https://e.com'},
        },
        {'insert': '\n'},
      ]);
      expect(link[0]['content'][0]['marks'], [
        {
          'type': 'link',
          'attrs': {'href': 'https://e.com'},
        },
      ]);
    });

    test('underline → underline mark', () {
      final c = content([
        {
          'insert': 'u',
          'attributes': {'underline': true},
        },
        {'insert': '\n'},
      ]);
      expect(c[0]['content'][0]['marks'], [
        {'type': 'underline'},
      ]);
    });

    test('heading 带 level', () {
      final c = content([
        {'insert': 'T'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
      ]);
      expect(c[0]['type'], 'heading');
      expect(c[0]['attrs'], {'level': 2});
    });

    test('code-block 合并为一个 codeBlock', () {
      final c = content([
        {'insert': 'a()'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
        {'insert': 'b()'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ]);
      expect(c.length, 1);
      expect(c[0]['type'], 'codeBlock');
      expect(c[0]['content'][0]['text'], 'a()\nb()');
    });
  });

  group('QuillDeltaToTiptap — 列表 / 引用', () {
    test('相邻无序列表项合一个 bulletList', () {
      final c = content([
        {'insert': 'one'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'two'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);
      expect(c.length, 1);
      expect(c[0]['type'], 'bulletList');
      expect((c[0]['content'] as List).length, 2);
      expect(c[0]['content'][0], {
        'type': 'listItem',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'one'},
            ],
          },
        ],
      });
    });

    test('ordered 列表 → orderedList', () {
      final c = content([
        {'insert': 'x'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ]);
      expect(c[0]['type'], 'orderedList');
    });

    test('复选列表 checked/unchecked → taskList + taskItem.checked', () {
      final c = content([
        {'insert': 'done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': 'todo'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      expect(c.length, 1);
      expect(c[0]['type'], 'taskList');
      final items = c[0]['content'] as List;
      expect(items.length, 2);
      expect(items[0]['type'], 'taskItem');
      expect(items[0]['attrs'], {'checked': true});
      expect(items[1]['attrs'], {'checked': false});
    });

    test('相邻引用行合一个 blockquote', () {
      final c = content([
        {'insert': 'q1'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
        {'insert': 'q2'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ]);
      expect(c.length, 1);
      expect(c[0]['type'], 'blockquote');
      expect((c[0]['content'] as List).length, 2);
    });
  });

  group('QuillDeltaToTiptap — embed', () {
    test('图片 / 音频 / 视频 → 对应一等节点（不退化成图片）', () {
      expect(content([
        {
          'insert': {'image': 'image-1.jpg'},
        },
        {'insert': '\n'},
      ]).last, {
        'type': 'image',
        'attrs': {'src': 'image-1.jpg'},
      });
      expect(content([
        {
          'insert': {'audio': 'audio-1.m4a'},
        },
        {'insert': '\n'},
      ]).last, {
        'type': 'audio',
        'attrs': {'filename': 'audio-1.m4a'},
      });
      expect(content([
        {
          'insert': {'video': 'video-1.mp4'},
        },
        {'insert': '\n'},
      ]).last, {
        'type': 'video',
        'attrs': {'filename': 'video-1.mp4'},
      });
    });

    test('有序列表里的图片：保留为该 listItem 内的 image 节点', () {
      final c = content([
        {'insert': 'one'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {
          'insert': {'image': 'image-x.jpg'},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ]);
      expect(c.length, 1);
      expect(c[0]['type'], 'orderedList');
      final items = c[0]['content'] as List;
      expect(items.length, 2);
      expect(items[1]['content'], [
        {
          'type': 'image',
          'attrs': {'src': 'image-x.jpg'},
        },
      ]);
    });
  });

  group('QuillDeltaToTiptap — 旧首行缩进 embed', () {
    test('text_indent 占位被丢弃，段落文字保留（不崩、不留空节点）', () {
      // 旧「首行缩进」日记：每段行首一个 {"insert":{"text_indent":"2"}}，与段落文字同一行。
      // 迁移到 tiptap 后首行缩进改由全局 CSS 实现，故此占位应被静默丢弃、文字原样保留。
      expect(content([
        {
          'insert': {'text_indent': '2'},
        },
        {'insert': '缩进段落'},
        {'insert': '\n'},
      ]), [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '缩进段落'},
          ],
        },
      ]);
    });

    test('多段均带 text_indent：逐段丢占位、保留文字', () {
      expect(content([
        {
          'insert': {'text_indent': '2'},
        },
        {'insert': '第一段'},
        {'insert': '\n'},
        {
          'insert': {'text_indent': '2'},
        },
        {'insert': '第二段'},
        {'insert': '\n'},
      ]), [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '第一段'},
          ],
        },
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '第二段'},
          ],
        },
      ]);
    });
  });
}
