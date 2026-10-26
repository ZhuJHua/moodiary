import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_export/src/presentation/image_card/blocks.dart';
import 'package:moodiary_export/src/presentation/image_card/card.dart';
import 'package:moodiary_export/src/presentation/image_card/card_style.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

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

Map<String, dynamic> _hr([Map<String, dynamic>? attrs]) => {
  'type': 'horizontalRule',
  'attrs': ?attrs,
};

ImageCardStyle _cardStyle() {
  const text = TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF111111));
  return const ImageCardStyle(
    brightness: .light,
    widthDp: 400,
    watermark: false,
    background: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    muted: Color(0xFF555555),
    outline: Color(0xFF777777),
    hairline: Color(0xFFCCCCCC),
    accent: Color(0xFF2B5CB8),
    codeSurface: Color(0xFFEEEEEE),
    highlight: Color(0xFFFFF0A0),
    placeholder: Color(0xFFDDDDDD),
    onMedia: Color(0xFFFFFFFF),
    mediaScrim: Color(0x73000000),
    body: text,
    bodyStrong: text,
    title: text,
    dateAnchor: text,
    meta: text,
    metaStrong: text,
    mono: text,
    codeTheme: {},
  );
}

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
            'attrs': {
              'src': 'image-abc.webp',
              'widthPercent': 50,
              'name': '封面',
            },
          },
          {
            'type': 'image',
            'attrs': {'src': 'https://example.com/a.png', 'alt': '旧 alt'},
          },
        ]),
      );

      final local = result.blocks[0] as IrBlock_Image;
      expect(local.path, '/data/image/image-abc.webp');
      expect(local.isExternal, isFalse);
      expect(local.widthPercent, 50);
      expect(local.alt, '封面');

      final external = result.blocks[1] as IrBlock_Image;
      expect(external.path, 'https://example.com/a.png');
      expect(external.isExternal, isTrue);
      expect(external.alt, '旧 alt');
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

    test('v2 音视频读 src，宽度百分比兼容小数', () {
      final result = _convert(
        _doc([
          {
            'type': 'video',
            'attrs': {'src': 'video-x.mp4', 'widthPercent': 50.0, 'name': '海边'},
          },
          {
            'type': 'audio',
            'attrs': {'src': 'audio-y.m4a', 'name': ''},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-z.webp', 'widthPercent': 74.6},
          },
        ]),
      );

      final video = result.blocks[0] as IrBlock_Media;
      expect(video.filename, 'video-x.mp4');
      expect(video.name, '海边');
      expect(video.path, '/data/video/video-x.mp4');
      expect(video.coverPath, '/data/thumbnail/video-x.mp4');
      expect(video.widthPercent, 50);

      final audio = result.blocks[1] as IrBlock_Media;
      expect(audio.filename, 'audio-y.m4a');
      expect(audio.name, isNull);
      expect(audio.widthPercent, isNull);

      expect((result.blocks[2] as IrBlock_Image).widthPercent, 75);
    });

    test('horizontalRule 读线型，只有文字线保留标签', () {
      final result = _convert(
        _doc([
          _hr(),
          _hr({'variant': 'dashed', 'label': '被忽略'}),
          _hr({'variant': 'text', 'label': '第二天'}),
          _hr({'variant': 'text', 'label': ''}),
          _hr({'variant': 'zigzag'}),
          _hr({'variant': 'double', 'label': null}),
        ]),
      );
      final dividers = result.blocks.cast<IrBlock_Divider>();
      expect(dividers.map((d) => d.variant), [
        IrDividerVariant.solid,
        IrDividerVariant.dashed,
        IrDividerVariant.text,
        IrDividerVariant.text,
        IrDividerVariant.solid,
        IrDividerVariant.double,
      ]);
      expect(dividers.map((d) => d.label), [
        null,
        null,
        '第二天',
        null,
        null,
        null,
      ]);
      expect(dividers.map((d) => d.visibleLabel).nonNulls, ['第二天']);
    });

    test('highlight 标记进 IR，并参与相邻片段合并', () {
      final result = _convert(
        _doc([
          _para([
            _text('普通'),
            _text('重', [
              {
                'type': 'highlight',
                'attrs': {'color': null},
              },
            ]),
            _text('点', [
              {'type': 'highlight'},
            ]),
          ]),
        ]),
      );
      final spans = (result.blocks.single as IrBlock_Paragraph).spans;
      expect(spans.map((s) => s.text), ['普通', '重点']);
      expect(spans.map((s) => s.highlight), [false, true]);
      expect(spans.last.isPlain, isFalse);
    });

    test('attachment 解析成附件块，路径落在 file 目录', () {
      final result = _convert(
        _doc([
          {
            'type': 'attachment',
            'attrs': {
              'src': 'file-abc.pdf',
              'name': '体检报告.pdf',
              'mime': 'application/pdf',
              'size': 2048.0,
            },
          },
          {
            'type': 'attachment',
            'attrs': {'src': 'file-def.bin', 'name': null, 'size': -1},
          },
          {
            'type': 'attachment',
            'attrs': {'name': '没有 src'},
          },
        ]),
      );
      expect(result.unsupportedNodes, isEmpty);
      expect(result.blocks, hasLength(2));

      final full = result.blocks[0] as IrBlock_Attachment;
      expect(full.name, '体检报告.pdf');
      expect(full.filename, 'file-abc.pdf');
      expect(full.path, '/data/file/file-abc.pdf');
      expect(full.mime, 'application/pdf');
      expect(full.size, 2048);

      final bare = result.blocks[1] as IrBlock_Attachment;
      expect(bare.name, 'file-def.bin');
      expect(bare.mime, isNull);
      expect(bare.size, isNull);
    });

    test('文件大小按 1024 进位，小于 10 保留一位小数', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1023), '1023 B');
      expect(formatByteSize(1536), '1.5 KB');
      expect(formatByteSize(10 * 1024), '10 KB');
      expect(formatByteSize(5 * 1024 * 1024 + 300 * 1024), '5.3 MB');
      expect(formatByteSize(3 * 1024 * 1024 * 1024), '3.0 GB');
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
            'attrs': {'src': 'image-abc.webp', 'name': '封面_1'},
          },
        ]),
      );
      expect(
        MarkdownWriter.write(doc, _noMeta),
        r'![封面\_1](assets/image/image-abc.webp)',
      );
    });

    test('视频 / 音频按种类分目录引用', () {
      final doc = _convert(
        _doc([
          {
            'type': 'video',
            'attrs': {'filename': 'video-abc.mp4', 'name': '海边[1]'},
          },
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-abc.m4a'},
          },
        ]),
      );
      final md = MarkdownWriter.write(doc, _noMeta);
      expect(md, contains(r'：海边\[1\]](assets/video/video-abc.mp4)'));
      expect(md, contains('：audio-abc.m4a](assets/audio/audio-abc.m4a)'));
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

    test('各种分隔线都降级为 ---', () {
      final doc = _convert(
        _doc([
          _hr({'variant': 'wavy'}),
          _hr({'variant': 'text', 'label': '第二天'}),
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '---\n\n---');
    });

    test('字面等号被转义，回读不成高亮也不成 setext 标题', () {
      final doc = _convert(
        _doc([
          _para([
            _text('重点', [
              {'type': 'highlight'},
            ]),
            _text(' a ==b== c\n==='),
          ]),
        ]),
      );
      final md = MarkdownWriter.write(doc, _noMeta);
      expect(md, '==重点== a \\=\\=b\\=\\= c\\\n\\=\\=\\=');
      final back = jsonDecode(MarkdownToTiptap.convert(md)!) as Map;
      final para = (back['content'] as List).single as Map;
      expect(para['type'], 'paragraph');
      final nodes = (para['content'] as List).cast<Map>();
      String text(bool highlighted) => nodes
          .where(
            (n) => n['type'] == 'text' && (n['marks'] != null) == highlighted,
          )
          .map((n) => n['text'])
          .join();
      expect(text(false), ' a ==b== c===');
      expect(text(true), '重点');
      expect(nodes.where((n) => n['type'] == 'hardBreak'), hasLength(1));
    });

    test('高亮在 GFM 写成 ==x==，CommonMark 下只留原文', () {
      final doc = _convert(
        _doc([
          _para([
            _text('重点', [
              {'type': 'highlight'},
            ]),
          ]),
        ]),
      );
      expect(MarkdownWriter.write(doc, _noMeta), '==重点==');
      expect(
        MarkdownWriter.write(
          doc,
          const MarkdownOptions(
            frontMatter: false,
            includeTitle: false,
            dialect: .commonMark,
          ),
        ),
        '重点',
      );
    });

    test('附件写成指向 assets/file 的链接', () {
      final doc = _convert(
        _doc([
          {
            'type': 'attachment',
            'attrs': {'src': 'file-abc.pdf', 'name': '报告_v2.pdf'},
          },
        ]),
      );
      expect(
        MarkdownWriter.write(doc, _noMeta),
        r'[报告\_v2.pdf](assets/file/file-abc.pdf)',
      );
      expect(
        MarkdownWriter.write(
          doc,
          const MarkdownOptions(
            frontMatter: false,
            includeTitle: false,
            mediaMode: .absolute,
          ),
        ),
        r'[报告\_v2.pdf](/data/file/file-abc.pdf)',
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

  testWidgets(
    'share card uses stored palette and export brightness in a detached tree',
    (tester) async {
      final storage = MemoryKVStorage();
      getIt.registerSingleton<IKVStorage>(storage);
      addTearDown(getIt.reset);
      MoodiaryKVs.moodPalette.set('blueOrange');
      final theme = buildMuiTheme(brightness: .dark);
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ImageCard(
            docs: [
              ExportDoc(
                id: 'mood',
                title: '',
                time: DateTime(2026),
                mood: .awful,
                blocks: const [],
              ),
            ],
            common: const ExportCommon(),
            style: ImageCardStyle.of(theme, widthDp: 400, watermark: false),
            images: const {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MoodGlyph), findsOneWidget);
      final context = tester.element(find.byType(MoodGlyph));
      expect(MoodPalette.of(context), MoodPalette.blueOrange);
      expect(context.theme.brightness, Brightness.dark);
      final chip = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((widget) => widget.decoration is BoxDecoration);
      expect(
        (chip.decoration! as BoxDecoration).color?.withValues(alpha: 1),
        MoodPalette.blueOrange.color(.awful, theme.colorScheme),
      );
    },
  );

  group('IrBlockRenderer', () {
    testWidgets('分隔线、附件、音视频名与高亮都能画出来', (tester) async {
      final style = _cardStyle();
      final renderer = IrBlockRenderer(style: style, images: const {});
      final doc = _convert(
        _doc([
          for (final variant in IrDividerVariant.values)
            _hr({'variant': variant.name, 'label': '第二天'}),
          {
            'type': 'attachment',
            'attrs': {
              'src': 'file-abc.pdf',
              'name': 'report.pdf',
              'size': 2048,
            },
          },
          {
            'type': 'audio',
            'attrs': {'src': 'audio-abc.m4a', 'name': '晨间录音'},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-abc.mp4'},
          },
          _para([
            _text('重点', [
              {'type': 'highlight'},
            ]),
          ]),
        ]),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: SizedBox(
            width: style.contentWidth,
            child: Column(children: renderer.blocks(doc.blocks)),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('第二天'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('晨间录音'), findsOneWidget);
      expect(find.text('video-abc.mp4'), findsOneWidget);

      TextSpan? highlighted;
      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        text.text.visitChildren((span) {
          if (span is TextSpan && span.text == '重点') highlighted = span;
          return highlighted == null;
        });
      }
      expect(highlighted?.style?.backgroundColor, style.highlight);
    });
  });
}
