import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';
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
    };
  }
}

void main() {
  late Directory root;
  late String md;
  late _FakeStore store;
  late ImportMediaStage stage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('md-import');
    md = p.join(root.path, 'a.md');
    File(md).writeAsStringSync('');
    for (final rel in [
      'assets/pic.jpg',
      'assets/my pic.jpg',
      'assets/video/clip.mp4',
      'assets/song.m4a',
      'assets/doc.pdf',
    ]) {
      File(p.join(root.path, rel))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0]);
    }
    File(p.join(root.parent.path, 'outside.jpg')).writeAsBytesSync([0]);
    store = _FakeStore();
    stage = ImportMediaStage(root, store);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    final outside = File(p.join(root.parent.path, 'outside.jpg'));
    if (outside.existsSync()) outside.deleteSync();
  });

  test('三类媒体改写成入库名，视频 / 音频统一为图片语法', () async {
    final out = await stage.rewrite(
      '![封面](assets/pic.jpg)\n'
      '[视频：clip.mp4](assets/video/clip.mp4)\n'
      '![](assets/song.m4a "title")',
      md,
    );
    expect(out, '![封面](image-1.jpg)\n![](video-2.mp4)\n![](audio-3.m4a)');
    expect(store.calls.map((c) => c.$2), [
      ImportMediaKind.image,
      ImportMediaKind.video,
      ImportMediaKind.audio,
    ]);
    expect(stage.missing, 0);
  });

  test('百分号编码与尖括号目标都能解析', () async {
    final out = await stage.rewrite(
      '![a](assets/my%20pic.jpg) ![b](<assets/my pic.jpg>)',
      md,
    );
    expect(out, '![a](image-1.jpg) ![b](image-1.jpg)');
    // 同一素材只落一次。
    expect(store.calls, hasLength(1));
  });

  test('外链与锚点原样；越界 / 绝对路径 / 非媒体的图片语法降成链接，不计缺失', () async {
    const source =
        '![x](https://example.com/x.png) [y](#top) '
        '![z](../outside.jpg) [doc](assets/doc.pdf) ![abs](/etc/pic.jpg)';
    final out = await stage.rewrite(source, md);
    expect(
      out,
      '![x](https://example.com/x.png) [y](#top) '
      '[z](../outside.jpg) [doc](assets/doc.pdf) [abs](/etc/pic.jpg)',
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

  test('相对路径按 md 所在目录解析', () async {
    final nested = Directory(p.join(root.path, 'sub'))..createSync();
    final nestedMd = p.join(nested.path, 'b.md');
    File(nestedMd).writeAsStringSync('');
    final out = await stage.rewrite('![](../assets/pic.jpg)', nestedMd);
    expect(out, '![](image-1.jpg)');
  });
}
