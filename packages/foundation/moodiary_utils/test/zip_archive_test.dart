import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zip-archive-test-');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('字节 + 直存文件往返', () async {
    final src = File(p.join(dir.path, 'media.bin'))
      ..writeAsBytesSync(List.generate(3 << 20, (i) => i * 31 & 0xff));
    final zipPath = p.join(dir.path, 'backup.zip');

    final zip = await ZipWriter.create(zipPath);
    await zip.addBytes(
      'manifest.json',
      Uint8List.fromList('{"version":4}'.codeUnits),
    );
    await zip.addFile('media/image/a.png', src.path);
    await zip.finish();

    final out = p.join(dir.path, 'out');
    await extractZip(zipPath: zipPath, destDir: out);

    expect(
      File(p.join(out, 'manifest.json')).readAsStringSync(),
      '{"version":4}',
    );
    expect(
      File(p.join(out, 'media/image/a.png')).readAsBytesSync(),
      src.readAsBytesSync(),
    );

    // 文件条目是 Stored，字节条目是 Deflate。
    final input = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeStream(input);
    expect(
      archive.find('media/image/a.png')!.compression,
      CompressionType.none,
    );
    expect(archive.find('manifest.json')!.compression, CompressionType.deflate);
    input.closeSync();
  });

  test('finish 之后不可再用；abort 后文件可删', () async {
    final zipPath = p.join(dir.path, 'a.zip');
    final zip = await ZipWriter.create(zipPath);
    await zip.finish();
    await expectLater(
      zip.addBytes('x', Uint8List(0)),
      throwsA(isA<ZipException>()),
    );

    final aborted = await ZipWriter.create(p.join(dir.path, 'b.zip'));
    await aborted.addBytes('x', Uint8List(4));
    await aborted.abort();
    await aborted.abort();
    expect(() => File(p.join(dir.path, 'b.zip')).deleteSync(), returnsNormally);
  });

  test('缺失的源文件报错，但写入器还能 abort', () async {
    final zip = await ZipWriter.create(p.join(dir.path, 'c.zip'));
    await expectLater(
      zip.addFile('missing', p.join(dir.path, 'nope')),
      throwsA(isA<ZipException>()),
    );
    await zip.abort();
  });

  test('拒绝逃出目标目录的条目', () async {
    final zipPath = p.join(dir.path, 'evil.zip');
    final encoder = ZipFileEncoder()..create(zipPath);
    encoder.addArchiveFile(ArchiveFile.string('../evil.txt', 'x'));
    encoder.closeSync();

    final out = p.join(dir.path, 'out');
    await expectLater(
      extractZip(zipPath: zipPath, destDir: out),
      throwsA(isA<ZipException>()),
    );
    expect(File(p.join(dir.path, 'evil.txt')).existsSync(), isFalse);
  });

  test('不是 zip 的文件报错', () async {
    final bogus = File(p.join(dir.path, 'bogus.zip'))
      ..writeAsStringSync('nope');
    await expectLater(
      extractZip(zipPath: bogus.path, destDir: p.join(dir.path, 'out')),
      throwsA(isA<ZipException>()),
    );
  });
}
