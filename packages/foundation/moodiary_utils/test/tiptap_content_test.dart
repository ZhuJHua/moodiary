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
  group('解析复用', () {
    test('同一正文引用复用实例，内容相等的新字符串重新解析', () {
      final content = _doc([
        _p([_text('正文')]),
      ]);
      final before = TiptapContent.parseCount;
      final parsed = TiptapContent.parse(content);
      expect(TiptapContent.parse(content), same(parsed));
      expect(TiptapContent.parseCount - before, 1);

      final fresh = String.fromCharCodes(content.codeUnits);
      expect(fresh, content);
      expect(identical(fresh, content), isFalse);
      expect(TiptapContent.parse(fresh), isNot(same(parsed)));
      expect(TiptapContent.parseCount - before, 2);
      expect(TiptapContent.parse(content), isNot(same(parsed)));
      expect(TiptapContent.parseCount - before, 3);
    });

    test('归一未改时返回原字符串，旧版归一与 v2 字符串相等', () {
      final content = jsonEncode(
        TiptapContent.newDoc([
          _p([_text('正文')]),
        ]),
      );
      expect(TiptapContent.normalize(content), same(content));
      final legacy = _doc([
        _p([_text('正文')]),
      ]);
      final parsed = TiptapContent.parse(legacy);
      expect(
        parsed.normalized,
        jsonEncode({
          'type': 'doc',
          'content': [
            _p([_text('正文')]),
          ],
          'attrs': {'v': 2},
        }),
      );
      expect(TiptapContent.normalize(legacy), same(parsed.normalized));
      expect(TiptapContent.normalize('不是 JSON'), same('不是 JSON'));
    });

    test('补媒体和改名不污染已缓存的正文', () {
      final content = jsonEncode(
        TiptapContent.newDoc([
          {
            'type': 'image',
            'attrs': {'src': 'image-a.jpg', 'name': '原名'},
          },
        ]),
      );
      final parsed = TiptapContent.parse(content);
      final added = TiptapContent.ensureMedia(
        content,
        images: ['image-b.jpg'],
        audios: [],
        videos: [],
      );
      final renamed = TiptapContent.mapMediaNames(content, (_, _, _) => '新名');
      expect(TiptapContent.parse(content), same(parsed));
      expect(parsed.normalized, same(content));
      expect(parsed.media.images, ['image-a.jpg']);
      expect(parsed.mediaNames, {'image-a.jpg': '原名'});
      expect(TiptapContent.parse(added).media.images, [
        'image-a.jpg',
        'image-b.jpg',
      ]);
      expect(TiptapContent.parse(renamed).mediaNames, {'image-a.jpg': '新名'});
    });
  });

  group('TiptapContent — TipTap 文档', () {
    test('plainText：文本块之间一个换行，无名媒体与分隔线不占行', () {
      final c = TiptapContent.parse(
        _doc([
          _p([_text('第一段')]),
          {'type': 'horizontalRule'},
          {
            'type': 'image',
            'attrs': {'src': 'image-a.png'},
          },
          {'type': 'horizontalRule'},
          _p([_text('第二段')]),
        ]),
      );
      expect(c.isDoc, isTrue);
      expect(c.plainText, '第一段\n第二段');
    });

    test('plainText：空段落照样占一行，首尾不 trim、空行不收敛', () {
      final c = TiptapContent.parse(
        _doc([
          {'type': 'paragraph'},
          _p([_text('  a  ')]),
          {'type': 'paragraph'},
          {'type': 'paragraph'},
          {'type': 'paragraph'},
          _p([_text('b')]),
          {'type': 'paragraph'},
        ]),
      );
      expect(c.plainText, '\n  a  \n\n\n\nb\n');
    });

    test('plainText：hardBreak → 换行，代码块保留自带换行', () {
      final c = TiptapContent.parse(
        _doc([
          _p([
            _text('上'),
            {'type': 'hardBreak'},
            _text('下'),
          ]),
          {
            'type': 'codeBlock',
            'attrs': {'language': null},
            'content': [_text('a\n\nb')],
          },
        ]),
      );
      expect(c.plainText, '上\n下\na\n\nb');
    });

    test('plainText：列表、任务、引用、表格的段落逐个分行', () {
      Map<String, dynamic> item(String type, String t) => {
        'type': type,
        if (type == 'taskItem') 'attrs': {'checked': false},
        'content': [
          _p([_text(t)]),
        ],
      };
      Map<String, dynamic> cell(String type, String t) => {
        'type': type,
        'content': [
          _p([_text(t)]),
        ],
      };
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'bulletList',
            'content': [
              item('listItem', '1'),
              {
                'type': 'listItem',
                'content': [
                  _p([_text('2')]),
                  {
                    'type': 'orderedList',
                    'content': [item('listItem', '2.1')],
                  },
                ],
              },
            ],
          },
          {
            'type': 'taskList',
            'content': [item('taskItem', 't')],
          },
          {
            'type': 'blockquote',
            'content': [
              _p([_text('q1')]),
              _p([_text('q2')]),
            ],
          },
          {
            'type': 'table',
            'content': [
              {
                'type': 'tableRow',
                'content': [
                  cell('tableHeader', 'h1'),
                  cell('tableHeader', 'h2'),
                ],
              },
              {
                'type': 'tableRow',
                'content': [cell('tableCell', 'c1'), cell('tableCell', 'c2')],
              },
            ],
          },
        ]),
      );
      expect(c.plainText, '1\n2\n2.1\nt\nq1\nq2\nh1\nh2\nc1\nc2');
    });

    test('plainText：有名字的媒体各占一行、按类型加标记，空名不占行', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'attachment',
            'attrs': {'src': 'file-x.pdf', 'name': '报告.pdf'},
          },
          _p([_text('正文')]),
          {
            'type': 'image',
            'attrs': {'src': 'image-a.png', 'name': '封面'},
          },
          {
            'type': 'audio',
            'attrs': {'src': 'audio-a.m4a', 'name': '晨间录音'},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-a.mp4', 'name': '海边'},
          },
          {
            'type': 'attachment',
            'attrs': {'src': 'file-y.pdf', 'name': ''},
          },
          _p([_text('尾')]),
        ]),
      );
      expect(
        c.plainText,
        '\uFDD4报告.pdf\uFDD0\n正文\n\uFDD1封面\uFDD0\n\uFDD3晨间录音\uFDD0\n'
        '\uFDD2海边\uFDD0\n尾',
      );
      expect(TiptapContent.countCharacters(c.plainText), 3);
    });

    test('plainText：用户文字和名字里的保留字符一律剔掉，名字里的换行变空格', () {
      final c = TiptapContent.parse(
        _doc([
          _p([
            _text('\uFDD1假\uFDD0图'),
            {
              'type': 'diaryLink',
              'attrs': {'id': 'a1', 'label': '\uFDEF链'},
            },
          ]),
          {
            'type': 'image',
            'attrs': {'src': 'image-a.png', 'name': ' 晚\uFDD0霞\n海边 '},
          },
          {
            'type': 'audio',
            'attrs': {'src': 'audio-a.m4a', 'name': '\uFDD0'},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-a.mp4', 'name': '\u0085影'},
          },
          _p([_text('尾')]),
        ]),
      );
      expect(c.plainText, '假图链\n\uFDD1晚霞 海边\uFDD0\n\uFDD2\u0085影\uFDD0\n尾');
    });

    test('plainText：未知节点不丢文本——含文本子节点的当文本块', () {
      final c = TiptapContent.parse(
        _doc([
          _p([_text('a')]),
          {
            'type': 'callout',
            'content': [_text('未知块')],
          },
          {
            'type': 'details',
            'content': [
              _p([_text('嵌套')]),
            ],
          },
        ]),
      );
      expect(c.plainText, 'a\n未知块\n嵌套');
    });

    test('plainText 计入双链标签，标签为空时用 id', () {
      final c = TiptapContent.parse(
        _doc([
          _p([
            _text('看这篇'),
            {
              'type': 'diaryLink',
              'attrs': {'id': 'a1', 'label': '去年今日'},
            },
            _text('和'),
            {
              'type': 'diaryLink',
              'attrs': {'id': 'b2', 'label': ''},
            },
            {
              'type': 'diaryLink',
              'attrs': {'id': 'c3', 'label': null},
            },
          ]),
        ]),
      );
      expect(c.plainText, '看这篇去年今日和b2c3');
    });

    test('media 按节点类型分流、去重且保序，附件进 files', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'image',
            'attrs': {'src': 'image-b.webp'},
          },
          {
            'type': 'audio',
            'attrs': {'src': 'audio-1.m4a'},
          },
          {
            'type': 'attachment',
            'attrs': {'src': 'file-1.pdf', 'name': 'a.pdf'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-a.webp'},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-1.mp4'},
          },
          {
            'type': 'image',
            'attrs': {'src': 'image-b.webp'},
          },
          {
            'type': 'attachment',
            'attrs': {'src': 'file-1.pdf', 'name': 'a.pdf'},
          },
        ]),
      );
      expect(c.media.images, ['image-b.webp', 'image-a.webp']);
      expect(c.media.audios, ['audio-1.m4a']);
      expect(c.media.videos, ['video-1.mp4']);
      expect(c.media.files, ['file-1.pdf']);
    });

    test('media 读 v1 的 filename（先归一化再收集）', () {
      final c = TiptapContent.parse(
        _doc([
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-1.m4a'},
          },
          {
            'type': 'video',
            'attrs': {'filename': 'video-1.mp4'},
          },
        ]),
      );
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
            'attrs': {'src': null},
          },
          {'type': 'attachment'},
        ]),
      );
      expect(c.media.images, isEmpty);
      expect(c.media.audios, isEmpty);
      expect(c.media.videos, isEmpty);
      expect(c.media.files, isEmpty);
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

    test('产出已是 v2，归一化原样返回', () {
      final json = TiptapContent.wrapPlainText('a\nb');
      expect(TiptapContent.normalize(json), same(json));
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

    test('补回的节点是 v2 形状（src、附件四个 attrs），文档带 v: 2', () {
      final ensured = jsonDecode(
        TiptapContent.ensureMedia(
          _doc([
            _p([_text('x')]),
          ]),
          images: [],
          audios: ['audio-a.m4a'],
          videos: ['video-a.mp4'],
          files: ['file-a.pdf'],
        ),
      ) as Map<String, dynamic>;
      expect(ensured['attrs'], {'v': 2});
      expect((ensured['content'] as List).skip(1), [
        {
          'type': 'audio',
          'attrs': {'src': 'audio-a.m4a'},
        },
        {
          'type': 'video',
          'attrs': {'src': 'video-a.mp4'},
        },
        {
          'type': 'attachment',
          'attrs': {
            'src': 'file-a.pdf',
            'name': null,
            'mime': null,
            'size': null,
          },
        },
      ]);
    });

    test('全部在场时原样返回（字节不变）', () {
      final doc = _doc([
        {
          'type': 'image',
          'attrs': {'src': 'image-a.png'},
        },
      ]);
      expect(
        TiptapContent.ensureMedia(
          doc,
          images: ['image-a.png'],
          audios: [],
          videos: [],
        ),
        same(doc),
      );
    });

    test('整篇被判成代码块（缩进日记）时图片引用救得回来', () {
      final doc = _doc([
        {
          'type': 'codeBlock',
          'content': [_text('今天天气很好。\n![](image-aaa.png)')],
        },
      ]);
      final media = TiptapContent.parse(
        TiptapContent.ensureMedia(
          doc,
          images: ['image-aaa.png'],
          audios: [],
          videos: [],
        ),
      ).media;
      expect(media.images, ['image-aaa.png']);
    });

    test('非 doc 输入原样返回，不抛出', () {
      expect(
        TiptapContent.ensureMedia(
          'not a doc',
          images: ['image-a.png'],
          audios: [],
          videos: [],
        ),
        'not a doc',
      );
    });

    test('空串与重复名安全（去重、忽略空名）', () {
      final doc = _doc([
        _p([_text('x')]),
      ]);
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
      final doc = _doc([
        _p([_text('x')]),
      ]);
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

  group('TiptapContent.countCharacters', () {
    test('去掉所有空白后按字素簇计数', () {
      expect(TiptapContent.countCharacters(''), 0);
      expect(TiptapContent.countCharacters(' \t\n\r　'), 0);
      expect(TiptapContent.countCharacters('a b\nc\td'), 4);
      expect(TiptapContent.countCharacters('今天 天气'), 4);
    });

    test('emoji、组合字符、ZWJ 序列各算一个', () {
      expect(TiptapContent.countCharacters('👍🏽'), 1);
      expect(TiptapContent.countCharacters('👨‍👩‍👧'), 1);
      expect(TiptapContent.countCharacters('é'), 1);
      expect(TiptapContent.countCharacters('🇨🇳 好'), 2);
    });
  });

  group('TiptapContent.normalize — v1 → v2', () {
    Map<String, dynamic> norm(Map<String, dynamic> doc) =>
        jsonDecode(TiptapContent.normalize(jsonEncode(doc)))
            as Map<String, dynamic>;

    Map<String, dynamic> v1(List<Map<String, dynamic>> content) => {
      'type': 'doc',
      'content': content,
    };

    Map<String, dynamic> first(Map<String, dynamic> doc) =>
        (doc['content'] as List).first as Map<String, dynamic>;

    test('doc 补 attrs.v = 2，保留其它 doc attrs', () {
      expect(norm(v1([_p([])]))['attrs'], {'v': 2});
      expect(
        norm({
          'type': 'doc',
          'attrs': {'v': 1, 'x': 'y'},
          'content': [_p([])],
        })['attrs'],
        {'v': 2, 'x': 'y'},
      );
    });

    test('audio / video：filename → src，丢掉 filename；已有 src 优先', () {
      final doc = norm(
        v1([
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-1.m4a'},
          },
          {
            'type': 'video',
            'attrs': {'filename': 'video-1.mp4', 'widthPercent': 50},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-2.mp4', 'filename': 'video-old.mp4'},
          },
        ]),
      );
      expect(doc['content'], [
        {
          'type': 'audio',
          'attrs': {'src': 'audio-1.m4a'},
        },
        {
          'type': 'video',
          'attrs': {'widthPercent': 50, 'src': 'video-1.mp4'},
        },
        {
          'type': 'video',
          'attrs': {'src': 'video-2.mp4'},
        },
      ]);
    });

    test('image：丢 width / height，widthPercent 只夹到 25..100、不吸附', () {
      Object? clamped(Object? raw) => first(
        norm(
          v1([
            {
              'type': 'image',
              'attrs': {'src': 'image-a.png', 'widthPercent': raw},
            },
          ]),
        ),
      )['attrs']['widthPercent'];
      expect(clamped(25), 25);
      expect(clamped(37), 37);
      expect(clamped(63), 63);
      expect(clamped(100), 100);
      expect(clamped(10), 25);
      expect(clamped(180), 100);
      expect(clamped(62.4), 62);
      expect(clamped('50'), isNull);
      expect(clamped(null), isNull);

      final image = first(
        norm(
          v1([
            {
              'type': 'image',
              'attrs': {
                'src': 'image-a.png',
                'alt': 'x',
                'title': null,
                'width': 640,
                'height': 480,
              },
            },
          ]),
        ),
      );
      expect(image['attrs'], {'src': 'image-a.png', 'name': 'x'});
    });

    test('image：name ??= alt ?? title（只认非空串），然后丢 alt / title', () {
      Map<String, dynamic> folded(Map<String, dynamic> attrs) => first(
        norm({
          'type': 'doc',
          'attrs': {'v': 2},
          'content': [
            {'type': 'image', 'attrs': attrs},
          ],
        }),
      )['attrs'];
      expect(folded({'src': 's', 'alt': 'a', 'title': 't'}), {
        'src': 's',
        'name': 'a',
      });
      expect(folded({'src': 's', 'alt': '', 'title': 't'}), {
        'src': 's',
        'name': 't',
      });
      expect(folded({'src': 's', 'name': 'n', 'alt': 'a'}), {
        'src': 's',
        'name': 'n',
      });
      expect(folded({'src': 's', 'name': '', 'alt': 'a'}), {
        'src': 's',
        'name': '',
      });
      expect(folded({'src': 's', 'name': null, 'alt': '', 'title': null}), {
        'src': 's',
        'name': null,
      });
      expect(folded({'src': 's', 'alt': null}), {'src': 's'});
    });

    test('diaryLink 丢 mentionSuggestionChar，id / label 不动', () {
      final paragraph = first(
        norm(
          v1([
            _p([
              {
                'type': 'diaryLink',
                'attrs': {
                  'id': 'a',
                  'label': 'L',
                  'mentionSuggestionChar': '[[',
                },
              },
            ]),
          ]),
        ),
      );
      expect((paragraph['content'] as List).single['attrs'], {
        'id': 'a',
        'label': 'L',
      });
    });

    test('link mark 只留 href，其它 mark 不动', () {
      final paragraph = first(
        norm(
          v1([
            _p([
              {
                'type': 'text',
                'text': 't',
                'marks': [
                  {'type': 'bold'},
                  {
                    'type': 'link',
                    'attrs': {
                      'href': 'https://e.com',
                      'target': '_blank',
                      'rel': 'noopener',
                      'class': null,
                    },
                  },
                ],
              },
            ]),
          ]),
        ),
      );
      expect((paragraph['content'] as List).single['marks'], [
        {'type': 'bold'},
        {
          'type': 'link',
          'attrs': {'href': 'https://e.com'},
        },
      ]);
    });

    test('horizontalRule：缺 attrs 补 solid / null，已有 variant 保留', () {
      final doc = norm(
        v1([
          {'type': 'horizontalRule'},
          {
            'type': 'horizontalRule',
            'attrs': {'variant': 'wavy'},
          },
          {
            'type': 'horizontalRule',
            'attrs': {'variant': 'text', 'label': '第二章'},
          },
        ]),
      );
      expect(
        [for (final n in doc['content'] as List) n['attrs']],
        [
          {'variant': 'solid', 'label': null},
          {'variant': 'wavy', 'label': null},
          {'variant': 'text', 'label': '第二章'},
        ],
      );
    });

    test('嵌套位置（列表、引用、表格）同样归一', () {
      final doc = norm(
        v1([
          {
            'type': 'blockquote',
            'content': [
              {
                'type': 'bulletList',
                'content': [
                  {
                    'type': 'listItem',
                    'content': [
                      _p([]),
                      {
                        'type': 'audio',
                        'attrs': {'filename': 'audio-n.m4a'},
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      );
      expect(TiptapContent.parse(jsonEncode(doc)).media.audios, [
        'audio-n.m4a',
      ]);
      expect(jsonEncode(doc), isNot(contains('filename')));
    });

    test('未知节点与 mark 原样保留', () {
      final unknown = {
        'type': 'callout',
        'attrs': {'filename': 'keep', 'emoji': '💡'},
        'content': [
          {
            'type': 'text',
            'text': 'x',
            'marks': [
              {
                'type': 'comment',
                'attrs': {'id': 'c1'},
              },
            ],
          },
        ],
      };
      expect(first(norm(v1([unknown]))), unknown);
    });

    test('已是 v2 → 同一个实例（字符串与 Map 都是）', () {
      final json = jsonEncode({
        'type': 'doc',
        'attrs': {'v': 2},
        'content': [
          {
            'type': 'image',
            'attrs': {'src': 'image-a.png', 'widthPercent': 50},
          },
          {
            'type': 'horizontalRule',
            'attrs': {'variant': 'solid', 'label': null},
          },
          _p([
            {
              'type': 'text',
              'text': 't',
              'marks': [
                {
                  'type': 'link',
                  'attrs': {'href': 'https://e.com'},
                },
              ],
            },
          ]),
        ],
      });
      expect(TiptapContent.normalize(json), same(json));
      final map = jsonDecode(json) as Map<String, dynamic>;
      expect(TiptapContent.normalizeDoc(map), same(map));
    });

    test('幂等：归一两次与一次相同，第二次返回同一实例', () {
      final once = TiptapContent.normalize(
        jsonEncode(
          v1([
            {
              'type': 'audio',
              'attrs': {'filename': 'audio-1.m4a'},
            },
            {'type': 'horizontalRule'},
            {
              'type': 'image',
              'attrs': {
                'src': 'image-1.png',
                'width': 3,
                'widthPercent': 40,
                'alt': 'a',
              },
            },
          ]),
        ),
      );
      expect(TiptapContent.normalize(once), same(once));
    });

    test('非 doc 输入与更高版本的 doc 原样返回', () {
      const md = '# 标题';
      expect(TiptapContent.normalize(md), same(md));
      final future = jsonEncode({
        'type': 'doc',
        'attrs': {'v': 3},
        'content': [
          {
            'type': 'audio',
            'attrs': {'filename': 'audio-1.m4a'},
          },
        ],
      });
      expect(TiptapContent.normalize(future), same(future));
    });

    test('归一不改输入对象', () {
      final input = v1([
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
      ]);
      final before = jsonEncode(input);
      TiptapContent.normalizeDoc(input);
      expect(jsonEncode(input), before);
    });
  });

  group('TiptapContent 媒体名称', () {
    final v1 = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.jpg', 'alt': ' 日落 '},
        },
        {
          'type': 'attachment',
          'attrs': {'src': 'file-1.pdf', 'name': '计划.pdf'},
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.jpg', 'name': '第二处'},
        },
      ],
    });

    test('isLegacy 只认没有 v 或 v 小于 2 的文档', () {
      expect(TiptapContent.parse(v1).isLegacy, isTrue);
      expect(
        TiptapContent.parse(TiptapContent.normalize(v1)).isLegacy,
        isFalse,
      );
      expect(TiptapContent.parse('纯文本').isLegacy, isFalse);
    });

    test('mediaNames 按 src 取第一个非空名称，归一后的 alt 也算', () {
      expect(TiptapContent.parse(v1).mediaNames, {
        'image-1.jpg': '日落',
        'file-1.pdf': '计划.pdf',
      });
    });

    test('mapMediaNames 认 v1 的 filename，没改返回原串', () {
      String? keep(String type, String src, String? name) => name;
      expect(identical(TiptapContent.mapMediaNames(v1, keep), v1), isTrue);
      final named = TiptapContent.mapMediaNames(
        v1,
        (type, src, name) => type == 'audio' ? '晨间' : name,
      );
      expect(TiptapContent.parse(named).mediaNames['audio-1.m4a'], '晨间');
      expect(TiptapContent.parse(named).isLegacy, isTrue);
      expect(
        identical(TiptapContent.mapMediaNames('纯文本', keep), '纯文本'),
        isTrue,
      );
    });
  });

  group('MediaMarkup', () {
    String desc(List<MarkupRun> runs) => runs
        .map(
          (r) => switch (r) {
            TextRun(:final text) => 'T($text)',
            MediaRun(:final kind, :final text) => 'M(${kind?.name}:$text)',
          },
        )
        .join(' ');

    test('成对标记切成文本段和媒体段，未知类型 kind 为 null', () {
      expect(
        desc(MediaMarkup.parse('a\n\uFDD1日落\uFDD0\nb\uFDE0新类型\uFDD0')),
        'T(a\n) M(image:日落) T(\nb) M(null:新类型)',
      );
    });

    test('截断：只有开始符算到结尾，只有结束符就丢掉它', () {
      expect(desc(MediaMarkup.parse('前\uFDD4报告')), 'T(前) M(attachment:报告)');
      expect(desc(MediaMarkup.parse('告.pdf\uFDD0后文')), 'T(告.pdf后文)');
    });

    test('body 去掉名字，forModel 换成方括号', () {
      const text = '今天\n\uFDD1日落\uFDD0\n\uFDD4计划.pdf\uFDD0';
      expect(MediaMarkup.body(text), '今天\n\n');
      expect(
        MediaMarkup.forModel(text),
        '今天\n[image: 日落]\n[attachment: 计划.pdf]',
      );
      expect(MediaMarkup.mark(.audio, ' a\nb '), '\uFDD3a b\uFDD0');
      expect(MediaMarkup.strip('x\uFDEFy\uFDD0'), 'xy');
    });
  });
}
