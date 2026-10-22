import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

class _FakeStore implements ImportMediaStore {
  final List<(String, ImportMediaKind)> calls = [];
  final Set<String> failing = {};
  var _n = 0;

  @override
  Future<String?> save(String path, ImportMediaKind kind) async {
    calls.add((path, kind));
    if (failing.contains(p.basename(path))) return null;
    _n++;
    final ext = p.extension(path);
    return switch (kind) {
      .image => 'image-$_n$ext',
      .video => 'video-$_n.mp4',
      .audio => 'audio-$_n$ext',
      .file => 'file-$_n$ext',
    };
  }
}

void main() {
  late Directory root;
  late Directory outsideRoot;
  late String md;
  late _FakeStore store;
  late ImportMediaStage stage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('md-import');
    outsideRoot = Directory.systemTemp.createTempSync('md-import-outside');
    md = p.join(root.path, 'a.md');
    File(md).writeAsStringSync('');
    for (final rel in [
      'assets/pic.jpg',
      'assets/my pic.jpg',
      'assets/video/clip.mp4',
      'assets/song.m4a',
      'assets/my_song[1].m4a',
      'assets/doc.pdf',
      'assets/file/file-old.pdf',
      'assets/file/file-shot.jpg',
      'assets/file-clip.mp4',
    ]) {
      File(p.join(root.path, rel))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0]);
    }
    File(p.join(outsideRoot.path, 'outside.jpg')).writeAsBytesSync([0]);
    store = _FakeStore();
    stage = ImportMediaStage(root, store);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    outsideRoot.deleteSync(recursive: true);
  });

  test('媒体改写成入库名并保留链接文字或标题，无名称才使用文件名', () async {
    final out = await stage.rewrite(
      '![封面](assets/pic.jpg)\n'
      '[视频：clip.mp4](assets/video/clip.mp4)\n'
      '![](assets/song.m4a "title")\n'
      '![](assets/my_song[1].m4a)',
      md,
    );
    expect(
      out,
      '![封面](image-1.jpg)\n![clip](video-2.mp4)\n![title](audio-3.m4a)\n'
      r'![my\_song\[1\]](audio-4.m4a)',
    );
    final json = MarkdownToTiptap.convert(out);
    expect(
      [
        for (final n in jsonDecode(json!)['content'] as List)
          (n['type'], n['attrs']['name']),
      ],
      [
        ('image', '封面'),
        ('video', 'clip'),
        ('audio', 'title'),
        ('audio', 'my_song[1]'),
      ],
    );
    expect(store.calls.map((c) => c.$2), [
      ImportMediaKind.image,
      ImportMediaKind.video,
      ImportMediaKind.audio,
      ImportMediaKind.audio,
    ]);
    expect(stage.missing, 0);
  });

  test('媒体文件的自定义名称和转义字符经过导入后仍保留', () async {
    final out = await stage.rewrite(
      r'![晨间\[录音\]](assets/song.m4a)'
      '\n\n'
      '[海边](assets/video/clip.mp4)\n\n'
      '![](assets/pic.jpg "封面")',
      md,
    );
    final nodes = jsonDecode(MarkdownToTiptap.convert(out)!)['content'] as List;
    expect(nodes.map((n) => n['attrs']['name']), ['晨间[录音]', '海边', '封面']);
  });

  test('音视频 Markdown 导出后再导入保留名称，类型前缀不进入名称', () async {
    for (final rel in [
      'audio/audio-original.m4a',
      'video/video-original.mp4',
    ]) {
      File(p.join(root.path, 'assets', rel))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0]);
    }
    final doc = TiptapToIr.convert(
      id: 'd',
      title: '',
      time: DateTime(2026),
      content: jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'audio',
            'attrs': {'src': 'audio-original.m4a', 'name': '晨间[录音]'},
          },
          {
            'type': 'video',
            'attrs': {'src': 'video-original.mp4', 'name': '海边'},
          },
        ],
      }),
      resolvePath: (kind, name) => '/data/$kind/$name',
    );
    final exported = MarkdownWriter.write(
      doc,
      const MarkdownOptions(frontMatter: false, includeTitle: false),
    );
    final rewritten = await stage.rewrite(exported, md);
    final nodes =
        jsonDecode(MarkdownToTiptap.convert(rewritten)!)['content'] as List;
    expect(nodes.map((n) => n['attrs']['name']), ['晨间[录音]', '海边']);

    final english = await stage.rewrite('[Audio：Morning](assets/song.m4a)', md);
    final audio =
        (jsonDecode(MarkdownToTiptap.convert(english)!)['content'] as List)
            .single;
    expect(audio['attrs']['name'], 'Morning');
  });

  test('百分号编码与尖括号目标都能解析', () async {
    final out = await stage.rewrite(
      '![a](assets/my%20pic.jpg) ![b](<assets/my pic.jpg>)',
      md,
    );
    expect(out, '![a](image-1.jpg) ![b](image-1.jpg)');
    expect(store.calls, hasLength(1));
  });

  test('外链与锚点原样；越界 / 绝对路径 / 非媒体的图片语法降成链接，不计缺失', () async {
    final outside = '../${p.basename(outsideRoot.path)}/outside.jpg';
    final source =
        '![x](https://example.com/x.png) [y](#top) '
        '![z]($outside) [doc](assets/doc.pdf) ![abs](/etc/pic.jpg)';
    final out = await stage.rewrite(source, md);
    expect(
      out,
      '![x](https://example.com/x.png) [y](#top) '
      '[z]($outside) [doc](assets/doc.pdf) [abs](/etc/pic.jpg)',
    );
    expect(store.calls, isEmpty);
    expect(stage.missing, 0);
  });

  test('缺文件与入库失败降成普通链接并计数', () async {
    store.failing.add('pic.jpg');
    final out = await stage.rewrite(
      '![a](assets/nope.jpg) ![b](assets/pic.jpg) [c](assets/nope.jpg)',
      md,
    );
    expect(
      out,
      '[a](assets/nope.jpg) [b](assets/pic.jpg) [c](assets/nope.jpg)',
    );
    expect(stage.missing, 3);
  });

  group('AppImportMediaStore.sameFileContent', () {
    File make(String name, List<int> bytes) =>
        File(p.join(root.path, name))..writeAsBytesSync(bytes);

    test('同长且三段抽样指纹相同为同一文件；长度、头、中、尾任一不同则不是', () async {
      final big = List<int>.generate(200 * 1024, (i) => i % 251);
      final a = make('a.bin', big);
      final b = make('b.bin', List.of(big));
      expect(await AppImportMediaStore.sameFileContent(a, b), isTrue);

      final tail = List.of(big)..[big.length - 1] = 7;
      expect(
        await AppImportMediaStore.sameFileContent(a, make('c.bin', tail)),
        isFalse,
      );
      final middle = List.of(big)..[big.length ~/ 2] = 9;
      expect(
        await AppImportMediaStore.sameFileContent(a, make('m.bin', middle)),
        isFalse,
      );
      final head = List.of(big)..[3] = 9;
      expect(
        await AppImportMediaStore.sameFileContent(a, make('d.bin', head)),
        isFalse,
      );
      expect(
        await AppImportMediaStore.sameFileContent(a, make('e.bin', [1, 2])),
        isFalse,
      );
      expect(
        await AppImportMediaStore.sameFileContent(
          make('f.bin', const []),
          make('g.bin', const []),
        ),
        isTrue,
      );
    });
  });

  test('assets/file/ 下的链接入库为附件，文字保留，mime 与大小可查', () async {
    final out = await stage.rewrite(
      '[报告.pdf](assets/file/file-old.pdf) [缺](assets/file/gone.zip) '
      '![图](assets/file/file-old.pdf) [截图.jpg](assets/file/file-shot.jpg) '
      '[录像.mp4](assets/file-clip.mp4)',
      md,
    );
    expect(
      out,
      '[报告.pdf](file-1.pdf) [缺](assets/file/gone.zip) '
      '[图](assets/file/file-old.pdf) [截图.jpg](file-2.jpg) '
      '[录像.mp4](file-3.mp4)',
    );
    expect(store.calls.map((c) => c.$2), everyElement(ImportMediaKind.file));
    expect(stage.missing, 1);
    expect(stage.attachmentInfo('file-1.pdf'), (
      mime: 'application/pdf',
      size: 1,
    ));
    expect(stage.attachmentInfo('nope'), isNull);
  });

  test('附件链接文字为空时用原文件名，保证附件总有名字', () async {
    final out = await stage.rewrite('[ ](assets/file/file-shot.jpg)', md);
    expect(out, r'[file\-shot\.jpg](file-1.jpg)');
    final json = MarkdownToTiptap.convert(
      out,
      attachmentInfo: stage.attachmentInfo,
    );
    final node = (jsonDecode(json!)['content'] as List).single as Map;
    expect(node['attrs']['name'], 'file-shot.jpg');
  });

  test('导出的附件链接回读仍是附件：名字带方括号、扩展名像图片', () async {
    final doc = TiptapToIr.convert(
      id: 'd',
      title: '',
      time: DateTime(2026),
      content: jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'attachment',
            'attrs': {'src': 'file-shot.jpg', 'name': r'图[1]\.jpg'},
          },
        ],
      }),
      resolvePath: (kind, name) => '/data/$kind/$name',
    );
    final exported = MarkdownWriter.write(
      doc,
      const MarkdownOptions(frontMatter: false, includeTitle: false),
    );
    final out = await stage.rewrite(exported, md);
    expect(out, r'[图\[1\]\\.jpg](file-1.jpg)');
    expect(store.calls.single.$2, ImportMediaKind.file);

    final json = MarkdownToTiptap.convert(
      out,
      attachmentInfo: stage.attachmentInfo,
    );
    final node = (jsonDecode(json!)['content'] as List).single as Map;
    expect(node['type'], 'attachment');
    expect(node['attrs'], {
      'src': 'file-1.jpg',
      'name': r'图[1]\.jpg',
      'mime': 'image/jpeg',
      'size': 1,
    });
  });

  test('相对路径按 md 所在目录解析', () async {
    final nested = Directory(p.join(root.path, 'sub'))..createSync();
    final nestedMd = p.join(nested.path, 'b.md');
    File(nestedMd).writeAsStringSync('');
    final out = await stage.rewrite('![](../assets/pic.jpg)', nestedMd);
    expect(out, '![](image-1.jpg)');
  });
}
