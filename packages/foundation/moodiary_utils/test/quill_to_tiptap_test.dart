import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

List<dynamic> convert(List<Map<String, dynamic>> ops) {
  final json = QuillDeltaToTiptap.convert(jsonEncode(ops));
  expect(json, isNotNull);
  return (jsonDecode(json!) as Map<String, dynamic>)['content'] as List;
}

Map<String, dynamic> codeLine(String text) => {
  'insert': '$text\n',
  'attributes': {'code-block': true},
};

Map<String, dynamic> _doc(List<Map<String, dynamic>> ops) =>
    jsonDecode(QuillDeltaToTiptap.convert(jsonEncode(ops))!)
        as Map<String, dynamic>;

List<dynamic> _content(List<Map<String, dynamic>> ops) =>
    _doc(ops)['content'] as List<dynamic>;

void main() {
  group('QuillDeltaToTiptap — 基础', () {
    test('doc 结构 + 普通段落', () {
      final d = _doc([
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
      expect(
        _content([
          {'insert': '\n'},
        ]),
        [
          {'type': 'paragraph'},
        ],
      );
    });

    test('行内标记 bold/italic/strike/code/link', () {
      final c = _content([
        {'insert': 'a'},
        {
          'insert': 'b',
          'attributes': {'bold': true, 'italic': true},
        },
        {'insert': '\n'},
      ]);
      final marks = (c[0]['content'][1]['marks'] as List)
          .map((m) => m['type'])
          .toList();
      expect(marks, containsAll(['bold', 'italic']));

      final link = _content([
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
      final c = _content([
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
      final c = _content([
        {'insert': 'T'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
      ]);
      expect(c[0]['type'], 'heading');
      expect(c[0]['attrs'], {'level': 2});
    });
  });

  group('QuillDeltaToTiptap — 列表 / 引用', () {
    test('相邻无序列表项合一个 bulletList', () {
      final c = _content([
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

    test('复选列表 checked/unchecked → taskList + taskItem.checked', () {
      final c = _content([
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
      final c = _content([
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
      expect(
        _content([
          {
            'insert': {'image': 'image-1.jpg'},
          },
          {'insert': '\n'},
        ]).last,
        {
          'type': 'image',
          'attrs': {'src': 'image-1.jpg'},
        },
      );
      expect(
        _content([
          {
            'insert': {'audio': 'audio-1.m4a'},
          },
          {'insert': '\n'},
        ]).last,
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
      );
      expect(
        _content([
          {
            'insert': {'video': 'video-1.mp4'},
          },
          {'insert': '\n'},
        ]).last,
        {
          'type': 'video',
          'attrs': {'filename': 'video-1.mp4'},
        },
      );
    });

    test('有序列表里的图片：保留为 image 节点，首子补空段落满足 schema', () {
      final c = _content([
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
        {'type': 'paragraph'},
        {
          'type': 'image',
          'attrs': {'src': 'image-x.jpg'},
        },
      ]);
    });
  });

  group('QuillDeltaToTiptap — 旧首行缩进 embed', () {
    test('text_indent 占位被丢弃，段落文字保留（不崩、不留空节点）', () {
      expect(
        _content([
          {
            'insert': {'text_indent': '2'},
          },
          {'insert': '缩进段落'},
          {'insert': '\n'},
        ]),
        [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': '缩进段落'},
            ],
          },
        ],
      );
    });
  });

  group('QuillDeltaToTiptap code-block 行内 embed', () {
    test('纯文本代码块不受影响', () {
      final blocks = convert([
        {'insert': 'a'},
        codeLine(''),
        {'insert': 'b'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'a\nb'},
          ],
        },
      ]);
    });

    test('代码块中的空行保留', () {
      final blocks = convert([
        {'insert': 'a'},
        codeLine(''),
        codeLine(''),
        {'insert': 'b'},
        codeLine(''),
      ]);
      expect((blocks.single as Map)['content'], [
        {'type': 'text', 'text': 'a\n\nb'},
      ]);
    });

    test('代码行内图片切断代码块并保留为 image 节点', () {
      final blocks = convert([
        {'insert': 'before'},
        codeLine(''),
        {
          'insert': {'image': 'image-1.webp'},
        },
        codeLine(''),
        {'insert': 'after'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'before'},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'after'},
          ],
        },
      ]);
    });

    test('同一代码行文本与音频共存：文本入代码块、音频成节点', () {
      final blocks = convert([
        {'insert': 'code'},
        {
          'insert': {'audio': 'audio-1.m4a'},
        },
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'code'},
          ],
        },
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
      ]);
    });

    test('代码块以 embed 开头不产生空代码块', () {
      final blocks = convert([
        {
          'insert': {'video': 'video-1.mp4'},
        },
        codeLine(''),
        {'insert': 'tail'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'video',
          'attrs': {'filename': 'video-1.mp4'},
        },
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'tail'},
          ],
        },
      ]);
    });

    test('一行多个 embed 全部保留', () {
      final blocks = convert([
        {
          'insert': {'image': 'image-1.webp'},
        },
        {
          'insert': {'image': 'image-2.webp'},
        },
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-2.webp'},
        },
      ]);
    });
  });

  group('QuillDeltaToTiptap 常规路径回归', () {
    test('普通段落内嵌图片拆分为 paragraph/image/paragraph', () {
      final blocks = convert([
        {'insert': 'a'},
        {
          'insert': {'image': 'image-1.webp'},
        },
        {'insert': 'b\n'},
      ]);
      expect(blocks, [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'a'},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'b'},
          ],
        },
      ]);
    });

    test('恰好是 JSON 数组的裸文本不是 Delta：返回 null 走纯文本兜底，不产空文档', () {
      expect(QuillDeltaToTiptap.convert('["买菜","做饭"]'), isNull);
      expect(QuillDeltaToTiptap.convert('[2026]'), isNull);
      expect(QuillDeltaToTiptap.convert('[{"a":1}]'), isNull);
    });

    test('空数组是合法的空 Delta，产出空段落文档', () {
      final doc = jsonDecode(QuillDeltaToTiptap.convert('[]')!);
      expect(doc['content'], [
        {'type': 'paragraph'},
      ]);
    });

    test('任务列表行只有 embed 时 taskItem 首子同样补段落', () {
      final delta = jsonEncode([
        {
          'insert': {'audio': 'audio-b.m4a'},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      final doc = jsonDecode(QuillDeltaToTiptap.convert(delta)!);
      final item = (doc['content'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['type'] == 'taskList')['content'][0];
      final content = (item['content'] as List).cast<Map<String, dynamic>>();
      expect(content.first['type'], 'paragraph');
      expect(content.any((n) => n['type'] == 'audio'), isTrue);
    });
  });
}
