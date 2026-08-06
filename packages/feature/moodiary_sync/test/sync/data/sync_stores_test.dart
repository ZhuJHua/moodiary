import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:path/path.dart' as p;

import '../sync_test_harness.dart';

/// 用 package:file 的 MemoryFileSystem 测真正的生产媒体实现 [DiskSyncMediaFiles]
/// （默认的 LocalFileSystem 行为同 dart:io），不落真实磁盘。
void main() {
  late MemoryFileSystem fs;
  late DiskSyncMediaFiles media;
  const baseDir = '/support';

  setUp(() {
    fs = MemoryFileSystem();
    media = DiskSyncMediaFiles(fileSystem: fs, baseDir: baseDir);
  });

  Uint8List bytes(List<int> b) => Uint8List.fromList(b);

  test(
    'write creates parent dirs and read round-trips at <base>/<type>/<name>',
    () async {
      expect(await media.exists('image', 'a.jpg'), isFalse);
      await media.write('image', 'a.jpg', bytes([1, 2, 3]));

      expect(await media.exists('image', 'a.jpg'), isTrue);
      expect(await media.read('image', 'a.jpg'), bytes([1, 2, 3]));
      // 路径布局与 AppFiles.getRealPath 一致。
      expect(fs.file(p.join(baseDir, 'image', 'a.jpg')).existsSync(), isTrue);
    },
  );

  test('delete removes a file and is a no-op when absent', () async {
    await media.write('audio', 'x.m4a', bytes([9]));
    await media.delete('audio', 'x.m4a');
    expect(await media.exists('audio', 'x.m4a'), isFalse);
    // 不存在时删除不抛错。
    await media.delete('audio', 'x.m4a');
  });

  group('cleanUpReplaced', () {
    test(
      'removes media dropped by the new diary, keeps retained ones',
      () async {
        await media.write('image', 'keep.jpg', bytes([1]));
        await media.write('image', 'drop.jpg', bytes([2]));
        await media.write('audio', 'drop.m4a', bytes([3]));

        final oldDiary = buildDiary(
          id: 'd',
          images: ['keep.jpg', 'drop.jpg'],
          audios: ['drop.m4a'],
        );
        final newDiary = buildDiary(id: 'd', images: ['keep.jpg']);

        await media.cleanUpReplaced(oldDiary, newDiary);

        expect(await media.exists('image', 'keep.jpg'), isTrue);
        expect(await media.exists('image', 'drop.jpg'), isFalse);
        expect(await media.exists('audio', 'drop.m4a'), isFalse);
      },
    );

    test('removed video also drops its thumbnail', () async {
      const video = 'video-0123456789012345678901234567890123.mp4';
      const thumb = 'thumbnail-0123456789012345678901234567890123.jpeg';
      await media.write('video', video, bytes([1]));
      await media.write('video', thumb, bytes([2]));

      final oldDiary = buildDiary(id: 'd', videos: [video]);
      final newDiary = buildDiary(id: 'd');

      await media.cleanUpReplaced(oldDiary, newDiary);
      expect(await media.exists('video', video), isFalse);
      expect(
        await media.exists('video', thumb),
        isFalse,
        reason: '被移除视频的缩略图也应删除',
      );
    });

    test('retained video keeps its thumbnail', () async {
      const video = 'video-0123456789012345678901234567890123.mp4';
      const thumb = 'thumbnail-0123456789012345678901234567890123.jpeg';
      await media.write('video', video, bytes([1]));
      await media.write('video', thumb, bytes([2]));

      final diary = buildDiary(id: 'd', videos: [video]);
      await media.cleanUpReplaced(diary, diary);
      expect(await media.exists('video', video), isTrue);
      expect(await media.exists('video', thumb), isTrue);
    });
  });
}
