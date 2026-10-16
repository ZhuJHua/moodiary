import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Map<String, dynamic> _parse(String? json) =>
    jsonDecode(json!) as Map<String, dynamic>;

List<Map<String, dynamic>> _find(dynamic node, String type) {
  final out = <Map<String, dynamic>>[];
  void walk(dynamic n) {
    if (n is! Map) return;
    if (n['type'] == type) out.add(n.cast<String, dynamic>());
    final content = n['content'];
    if (content is List) content.forEach(walk);
  }

  walk(node);
  return out;
}

String _allText(dynamic node) {
  final buf = StringBuffer();
  void walk(dynamic n) {
    if (n is! Map) return;
    if (n['text'] is String) buf.write(n['text']);
    final content = n['content'];
    if (content is List) content.forEach(walk);
  }

  walk(node);
  return buf.toString();
}

Map<String, dynamic> _doc(String md) =>
    jsonDecode(MarkdownToTiptap.convert(md)!) as Map<String, dynamic>;

List<dynamic> _content(String md) => _doc(md)['content'] as List<dynamic>;

void main() {
  group('MarkdownToTiptap — 基础', () {
    test('doc 结构 + 段落', () {
      final d = _doc('hello world');
      expect(d['type'], 'doc');
      expect(d['attrs'], {'v': 2});
      expect(d['content'][0], {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': 'hello world'},
        ],
      });
    });

    test('空串 → 单个空段落', () {
      expect(_content('')[0], {'type': 'paragraph'});
    });

    test('heading 带 level', () {
      final c = _content('## 标题');
      expect(c[0]['type'], 'heading');
      expect(c[0]['attrs'], {'level': 2});
      expect(c[0]['content'][0]['text'], '标题');
    });

    test('行内 bold/italic/strike/code/link', () {
      final nodes =
          (_content('**b** _i_ ~~s~~ `c` [t](https://e.com)')[0]['content']
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
      final c = _content('- a\n- b');
      expect(c[0]['type'], 'bulletList');
      final items = c[0]['content'] as List;
      expect(items.length, 2);
      expect(items[0]['type'], 'listItem');
      expect(items[0]['content'][0]['type'], 'paragraph');
    });

    test('有序列表带 start', () {
      final c = _content('3. x\n4. y');
      expect(c[0]['type'], 'orderedList');
      expect(c[0]['attrs'], {'start': 3});
    });

    test('任务列表 → taskList + taskItem.checked', () {
      final c = _content('- [x] done\n- [ ] todo');
      expect(c[0]['type'], 'taskList');
      final items = c[0]['content'] as List;
      expect(items[0]['type'], 'taskItem');
      expect(items[0]['attrs'], {'checked': true});
      expect(items[1]['attrs'], {'checked': false});
      expect(items[0]['content'][0]['content'][0]['text'], 'done');
    });

    test('引用', () {
      final c = _content('> quote');
      expect(c[0]['type'], 'blockquote');
      expect(c[0]['content'][0]['type'], 'paragraph');
    });

    test('代码块带语言', () {
      final c = _content('```dart\nvar x = 1;\n```');
      expect(c[0]['type'], 'codeBlock');
      expect(c[0]['attrs'], {'language': 'dart'});
      expect(c[0]['content'][0]['text'], 'var x = 1;');
    });

    test('分隔线带 v2 默认 attrs', () {
      final c = _content('a\n\n---\n\nb');
      expect(c.firstWhere((n) => n['type'] == 'horizontalRule')['attrs'], {
        'variant': 'solid',
        'label': null,
      });
    });

    test('表格 → table / tableRow / tableHeader / tableCell', () {
      final c = _content('| A | B |\n|---|---|\n| 1 | 2 |');
      expect(c[0]['type'], 'table');
      final rows = c[0]['content'] as List;
      expect(rows[0]['content'][0]['type'], 'tableHeader');
      expect(rows[1]['content'][0]['type'], 'tableCell');
      expect(rows[0]['content'][0]['content'][0]['type'], 'paragraph');
    });
  });

  group('MarkdownToTiptap — 媒体', () {
    test('图片 / 音频 / 视频按文件名前缀分流为一等节点', () {
      expect(_content('![](image-1.jpg)')[0], {
        'type': 'image',
        'attrs': {'src': 'image-1.jpg'},
      });
      expect(_content('![](audio-1.m4a)')[0], {
        'type': 'audio',
        'attrs': {'src': 'audio-1.m4a'},
      });
      expect(_content('![](video-1.mp4)')[0], {
        'type': 'video',
        'attrs': {'src': 'video-1.mp4'},
      });
    });

    test('alt 成为三类媒体的 name，没有 alt 时取 title', () {
      expect(_content('![cover](image-1.jpg)')[0], {
        'type': 'image',
        'attrs': {'src': 'image-1.jpg', 'name': 'cover'},
      });
      expect(_content('![晨间录音](audio-1.m4a)')[0], {
        'type': 'audio',
        'attrs': {'src': 'audio-1.m4a', 'name': '晨间录音'},
      });
      expect(_content(r'![海边\_1](video-1.mp4)')[0], {
        'type': 'video',
        'attrs': {'src': 'video-1.mp4', 'name': '海边_1'},
      });
      expect(_content('![](image-2.jpg "旧标题")')[0], {
        'type': 'image',
        'attrs': {'src': 'image-2.jpg', 'name': '旧标题'},
      });
    });

    test('文字 + 图片混排：拆成段落 + image 块', () {
      final c = _content('text ![](image-1.jpg)');
      expect(c.any((n) => n['type'] == 'paragraph'), isTrue);
      expect(c.any((n) => n['type'] == 'image'), isTrue);
    });
  });

  group('MarkdownToTiptap — HTML 实体不外泄', () {
    test('正文里的 " & < > 原样保留，不转义成实体', () {
      final doc = _parse(MarkdownToTiptap.convert('He said "hi" & 1 < 2'));
      expect(_allText(doc), 'He said "hi" & 1 < 2');
    });

    test('行内代码与代码块同样不转义', () {
      final inline = _parse(MarkdownToTiptap.convert('前缀 `a<b` 后缀'));
      expect(_allText(inline), contains('a<b'));

      final block = _parse(
        MarkdownToTiptap.convert('```\nif (a < b && c) {}\n```'),
      );
      expect(_allText(block), 'if (a < b && c) {}');
    });
  });

  group('MarkdownToTiptap — 列表项 schema（paragraph block*）', () {
    test('列表项首子是图片时补空段落，媒体节点保留', () {
      final doc = _parse(
        MarkdownToTiptap.convert('- 早餐\n- ![](image-x.png)\n- 晚餐'),
      );
      for (final item in _find(doc, 'listItem')) {
        final content = item['content'] as List;
        expect((content.first as Map)['type'], 'paragraph');
      }
      final images = _find(doc, 'image');
      expect(images, hasLength(1));
      expect(images.single['attrs']['src'], 'image-x.png');
    });

    test('任务项首子是图片时同样补段落', () {
      final doc = _parse(MarkdownToTiptap.convert('- [ ] ![](image-y.png)'));
      final item = _find(doc, 'taskItem').single;
      expect(((item['content'] as List).first as Map)['type'], 'paragraph');
      expect(_find(doc, 'image').single['attrs']['src'], 'image-y.png');
    });
  });

  group('MarkdownToTiptap — Moodiary 方言', () {
    List<dynamic> inline(String md) => _content(md)[0]['content'] as List;

    test('[[label]](moodiary://diary/id) → diaryLink，保留 id 与标签', () {
      expect(inline('看 [[去年今日]](moodiary://diary/0190-ab) 吧'), [
        {'type': 'text', 'text': '看 '},
        {
          'type': 'diaryLink',
          'attrs': {'id': '0190-ab', 'label': '去年今日'},
        },
        {'type': 'text', 'text': ' 吧'},
      ]);
    });

    test('单层方括号与转义括号的标签同样识别', () {
      expect(inline('[x](moodiary://diary/a1)').single['attrs'], {
        'id': 'a1',
        'label': 'x',
      });
      expect(inline(r'[[a\]b]](moodiary://diary/a2)').single['attrs'], {
        'id': 'a2',
        'label': 'a]b',
      });
    });

    test('只有 scheme 没有 id 的链接仍是普通链接', () {
      final node = inline('[x](moodiary://diary/)').single;
      expect(node['type'], 'text');
      expect((node['marks'] as List).single['type'], 'link');
    });

    test('==x== → highlight；单个 = 不受影响', () {
      final nodes = inline('a ==亮== b = c');
      final lit = nodes.firstWhere((n) => n['text'] == '亮');
      expect(lit['marks'], [
        {'type': 'highlight'},
      ]);
      expect(_allText(_doc('a ==亮== b = c')), 'a 亮 b = c');
      expect(
        (inline('今天==很开心==啊')[1]['marks'] as List).single['type'],
        'highlight',
      );
    });

    test('不像高亮的 == 原样保留，不吞字符', () {
      for (final s in [
        'if a == b and c == d',
        'if a==b and c==d',
        'a===b===c',
        'a ====b==== c',
        '==a=b==',
        '== a ==',
        '==a ==',
      ]) {
        expect(_find(_doc(s), 'text').single, {'type': 'text', 'text': s});
      }
    });

    test('<u>x</u> → underline，可与其它标记叠加', () {
      final nodes = inline('前 <u>**粗**下</u> 后');
      final bold = nodes.firstWhere((n) => n['text'] == '粗');
      expect(
        (bold['marks'] as List).map((m) => m['type']),
        containsAll(['bold', 'underline']),
      );
      final plain = nodes.firstWhere((n) => n['text'] == '下');
      expect(plain['marks'], [
        {'type': 'underline'},
      ]);
      expect(_allText(_doc('前 <u>**粗**下</u> 后')), '前 粗下 后');
    });

    test('落单的 <u> 或 </u> 原样当文字，不吞内容', () {
      expect(_allText(_doc('a <u>b')), 'a <u>b');
      expect(_allText(_doc('a </u> b')), 'a </u> b');
    });

    test('独占一行的 [name](file-…) → attachment 块，两侧文字成段', () {
      final c = _content('看附件\n[报告.pdf](file-0190.pdf)\n结束');
      expect(c.map((n) => n['type']), ['paragraph', 'attachment', 'paragraph']);
      expect(c[1]['attrs'], {
        'src': 'file-0190.pdf',
        'name': '报告.pdf',
        'mime': null,
        'size': null,
      });
      expect(c[0]['content'], [
        {'type': 'text', 'text': '看附件'},
      ]);
      expect(c[2]['content'], [
        {'type': 'text', 'text': '结束'},
      ]);
      expect(
        _content('[a](file-1.pdf)\n[b](file-2.pdf)').map((n) => n['type']),
        ['attachment', 'attachment'],
      );
    });

    test('行内或标题里的 [name](file-…) 仍是普通链接', () {
      for (final s in [
        '看附件 [报告.pdf](file-0190.pdf) 结束',
        '# [报告.pdf](file-0190.pdf)',
      ]) {
        expect(_find(_doc(s), 'attachment'), isEmpty);
        final link = _find(
          _doc(s),
          'text',
        ).firstWhere((n) => n['text'] == '报告.pdf');
        expect(link['marks'], [
          {
            'type': 'link',
            'attrs': {'href': 'file-0190.pdf'},
          },
        ]);
      }
    });

    test('attachmentInfo 回填 mime 与 size；空链接文字不起名', () {
      final json = MarkdownToTiptap.convert(
        '[](file-1.zip)',
        attachmentInfo: (name) => (mime: 'application/zip', size: 42),
      );
      expect(_find(_parse(json), 'attachment').single['attrs'], {
        'src': 'file-1.zip',
        'name': null,
        'mime': 'application/zip',
        'size': 42,
      });
    });

    test('带路径或 scheme 的链接不是附件', () {
      expect(_find(_doc('[a](assets/file/file-1.pdf)'), 'attachment'), isEmpty);
      expect(_find(_doc('[a](https://x/file-1.pdf)'), 'attachment'), isEmpty);
    });
  });
}
