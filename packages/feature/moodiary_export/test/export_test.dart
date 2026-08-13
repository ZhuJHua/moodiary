import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';

String _resolve(String kind, String name) => '/data/$kind/$name';

ExportDoc _convert(Map<String, dynamic> doc, {String title = '标题'}) =>
    TiptapToIr.convert(
      id: 'diary-1',
      title: title,
      time: DateTime(2026, 8, 4, 9, 30),
      content: jsonEncode(doc),
      resolvePath: _resolve,
    );

Map<String, dynamic> _doc(List<Map<String, dynamic>> content) => {
  'type': 'doc',
  'content': content,
};

Map<String, dynamic> _text(String text, [List<Map<String, dynamic>>? marks]) =>
    {'type': 'text', 'text': text, 'marks': ?marks};

Map<String, dynamic> _para(List<Map<String, dynamic>> content) => {
  'type': 'paragraph',
  'content': content,
};

const _noMeta = MarkdownOptions(frontMatter: false, includeTitle: false);

void main() {
  group('TiptapToIr', () {
    test('段落与行内样式合并相邻同样式片段', () {
      final result = _convert(
        _doc([
          _para([
            _text('普通'),
            _text('粗', [
              {'type': 'bold'},
            ]),
            _text('体', [
              {'type': 'bold'},
            ]),
          ]),
        ]),
      );

      final block = result.blocks.single as IrBlock_Paragraph;
      expect(block.spans, hasLength(2));
      expect(block.spans[0].text, '普通');
      expect(block.spans[1].text, '粗体');
      expect(block.spans[1].bold, isTrue);
    });

    test('heading level 越界被夹取到 1-6', () {
      final result = _convert(
        _doc([
          {
            'type': 'heading',
            'attrs': {'level': 99},
            'content': [_text('大')],
          },
        ]),
      );
      expect((result.blocks.single as IrBlock_Heading).level, 6);
    });

    test('本地图片拼绝对路径，外链原样保留', () {
      final result = _convert(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': 'image-abc.webp', 'widthPercent': 50},
          },
          {
            'type': 'image',
            'attrs': {'src': 'https://example.com/a.png'},
          },
        ]),
      );

      final local = result.blocks[0] as IrBlock_Image;
      expect(local.path, '/data/image/image-abc.webp');
      expect(local.isExternal, isFalse);
      expect(local.widthPercent, 50);

      final external = result.blocks[1] as IrBlock_Image;
      expect(external.path, 'https://example.com/a.png');
      expect(external.isExternal, isTrue);
    });

    test('video 派生封面路径，audio 不派生', () {
      final result = _convert(
        _doc([
          {
            'type': 'video',
            'attrs': {'filename': 'video-x.mp4'},
          },
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-y.m4a'},
          },
        ]),
      );

      final video = result.blocks[0] as IrBlock_Media;
      expect(video.kind, 'video');
      expect(video.coverPath, '/data/thumbnail/video-x.mp4');

      final audio = result.blocks[1] as IrBlock_Media;
      expect(audio.kind, 'audio');
      expect(audio.coverPath, isNull);
    });

    test('diaryLink 保留目标 id 与标签', () {
      final result = _convert(
        _doc([
          _para([
            {
              'type': 'diaryLink',
              'attrs': {'id': 'target-9', 'label': '那天'},
            },
          ]),
        ]),
      );
      final span = (result.blocks.single as IrBlock_Paragraph).spans.single;
      expect(span.text, '那天');
      expect(span.diaryLinkId, 'target-9');
    });

    test('taskItem 的勾选状态进 IR', () {
      final result = _convert(
        _doc([
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'checked': true},
                'content': [
                  _para([_text('做完了')]),
                ],
              },
              {
                'type': 'taskItem',
                'attrs': {'checked': false},
                'content': [
                  _para([_text('还没做')]),
                ],
              },
            ],
          },
        ]),
      );
      final list = result.blocks.single as IrBlock_List;
      expect(list.isTask, isTrue);
      expect(list.items.map((i) => i.checked), [true, false]);
    });

    test('表格合并跨度非法时退回 1', () {
      final result = _convert(
        _doc([
          {
            'type': 'table',
            'content': [
              {
                'type': 'tableRow',
                'content': [
                  {
                    'type': 'tableHeader',
                    'attrs': {'colspan': 0, 'rowspan': -3},
                    'content': [
                      _para([_text('头')]),
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      );
      final cell =
          (result.blocks.single as IrBlock_Table).rows.single.cells.single;
      expect(cell.colspan, 1);
      expect(cell.rowspan, 1);
      expect(cell.header, isTrue);
    });

    test('未知节点记进 unsupportedNodes 而不是抛异常', () {
      final result = _convert(
        _doc([
          {'type': 'someFutureBlock'},
          _para([_text('正常内容')]),
        ]),
      );
      expect(result.unsupportedNodes, {'someFutureBlock'});
      expect(result.blocks, hasLength(1));
    });

    test('非 JSON 内容退化为单段纯文本', () {
      final result = TiptapToIr.convert(
        id: 'd',
        title: 't',
        time: DateTime(2026),
        content: '这是一篇旧的 markdown 日记',
        resolvePath: _resolve,
      );
      expect(
        (result.blocks.single as IrBlock_Paragraph).spans.single.text,
        '这是一篇旧的 markdown 日记',
      );
    });
  });

  group('MarkdownWriter', () {
    test('front matter 里的标题被引号包住并转义', () {
      final doc = _convert(_doc([]), title: '标题: 带冒号 "引号"');
      final md = MarkdownWriter.write(doc);
      expect(md, contains(r'title: "标题: 带冒号 \"引号\""'));
      expect(md, contains('id: diary-1'));
    });

    test('正文里的 markdown 特殊字符被转义', () {
      final doc = _convert(
        _doc([
          _para([_text('a*b_c[d]e')]),
        ]),
      );
      final md = MarkdownWriter.write(doc, _noMeta);
      expect(md, r'a\*b\_c\[d\]e');
    });

    test('行内代码不转义内容，围栏按内容加长', () {
      final doc = _convert(
        _doc([
          _para([
            _text('a``b', [
              {'type': 'code'},
            ]),
          ]),
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '```a``b```');
    });

    test('代码块围栏长于正文里最长的反引号串', () {
      final doc = _convert(
        _doc([
          {
            'type': 'codeBlock',
            'attrs': {'language': 'dart'},
            'content': [_text('print("```");')],
          },
        ]),
      );
      final md = MarkdownWriter.write(doc, _noMeta);
      expect(md, startsWith('````dart'));
      expect(md, endsWith('````'));
    });

    test('GFM 下任务列表写成勾选框，CommonMark 下降级', () {
      final doc = _convert(
        _doc([
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'checked': true},
                'content': [
                  _para([_text('买菜')]),
                ],
              },
            ],
          },
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '- [x] 买菜');
      expect(
        MarkdownWriter.write(
          doc,
          const MarkdownOptions(
            frontMatter: false,
            includeTitle: false,
            dialect: .commonMark,
          ),
        ),
        '- 买菜',
      );
    });

    test('有序列表沿用 start 属性', () {
      final doc = _convert(
        _doc([
          {
            'type': 'orderedList',
            'attrs': {'start': 3},
            'content': [
              {
                'type': 'listItem',
                'content': [
                  _para([_text('三')]),
                ],
              },
              {
                'type': 'listItem',
                'content': [
                  _para([_text('四')]),
                ],
              },
            ],
          },
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '3. 三\n4. 四');
    });

    test('嵌套列表按标记宽度缩进', () {
      final doc = _convert(
        _doc([
          {
            'type': 'bulletList',
            'content': [
              {
                'type': 'listItem',
                'content': [
                  _para([_text('外层')]),
                  {
                    'type': 'bulletList',
                    'content': [
                      {
                        'type': 'listItem',
                        'content': [
                          _para([_text('内层')]),
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '- 外层\n  - 内层');
    });

    test('引用块每行加前缀', () {
      final doc = _convert(
        _doc([
          {
            'type': 'blockquote',
            'content': [
              _para([_text('第一行')]),
              _para([_text('第二行')]),
            ],
          },
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '> 第一行\n>\n> 第二行');
    });

    test('表格单元格里的竖线被转义、换行被压平', () {
      final doc = _convert(
        _doc([
          {
            'type': 'table',
            'content': [
              {
                'type': 'tableRow',
                'content': [
                  {
                    'type': 'tableHeader',
                    'content': [
                      _para([_text('a|b')]),
                    ],
                  },
                  {
                    'type': 'tableHeader',
                    'content': [
                      _para([_text('c')]),
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      );
      final md = MarkdownWriter.write(doc, _noMeta);
      expect(md, contains(r'| a\|b | c |'));
      expect(md, contains('| --- | --- |'));
    });

    test('图片按相对路径引用，只取文件名', () {
      final doc = _convert(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': 'image-abc.webp', 'alt': '封面'},
          },
        ]),
      );
      expect(
        MarkdownWriter.write(doc, _noMeta),
        '![封面](assets/image-abc.webp)',
      );
    });

    test('硬换行写成反斜杠形式', () {
      final doc = _convert(
        _doc([
          _para([
            _text('上'),
            {'type': 'hardBreak'},
            _text('下'),
          ]),
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '上\\\n下');
    });

    test('链接 URL 里的空格与括号被百分号编码', () {
      final doc = _convert(
        _doc([
          _para([
            _text('看这里', [
              {
                'type': 'link',
                'attrs': {'href': 'https://a.com/x y(1)'},
              },
            ]),
          ]),
        ]),
      );
      expect(
        MarkdownWriter.write(doc, _noMeta),
        '[看这里](https://a.com/x%20y%281%29)',
      );
    });

    test('双链降级为 wiki 链接', () {
      final doc = _convert(
        _doc([
          _para([
            {
              'type': 'diaryLink',
              'attrs': {'id': 'target-9', 'label': '那天'},
            },
          ]),
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '[[那天]]');
    });
  });
}
