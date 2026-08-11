// 覆盖引擎的**路径式**媒体分支（_uploadMediaByFile / _downloadMediaByFile）。
//
// 其余同步用例用的 FakeMediaFiles 是纯内存的、realPath 返回 null，所以恒走字节路径；
// 生产上 S3/WebDAV 走的是这里这条。用生产的 DiskSyncMediaFiles 配临时目录即可打开它。
// 明文模式：加解密本体在 Rust，flutter test 里跑不了 FFI，但引擎侧的分支逻辑、
// 临时文件生命周期、空对象守卫都在这条路上。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/data/sync_stores.dart';
import 'package:path/path.dart' as p;

import '../sync_test_harness.dart';

void main() {
  late SyncLogger logger;
  late Directory root;
  late DiskSyncMediaFiles mediaFiles;
  late Directory cacheRoot;

  // 路径式分支要用 PlatformService 的缓存目录放临时密文；测试环境跑不了它的 init()
  // （path_provider 走平台通道），直接把 late final 赋一次。
  setUpAll(() {
    cacheRoot = Directory.systemTemp.createTempSync('media-file-path-cache');
    PlatformService.get().applicationCachePath = cacheRoot.path;
  });

  tearDownAll(() => cacheRoot.deleteSync(recursive: true));

  setUp(() async {
    logger = (await setUpSyncEnv()).logger;
    await configureBackend(.webdav);
    root = await Directory.systemTemp.createTemp('media-file-path-test');
    mediaFiles = DiskSyncMediaFiles(baseDir: root.path);
  });

  tearDown(() async {
    await root.delete(recursive: true);
    await tearDownSyncEnv();
  });

  IncrementalSyncEngine engineOn(FakeRemoteBackend backend, FakeDiaryStore d) =>
      IncrementalSyncEngine(
        backend,
        logger: logger,
        diaryStore: d,
        categoryStore: FakeCategoryStore(const [], d.tombstones),
        mediaInfoStore: FakeMediaInfoStore(const [], d.tombstones),
        tombstoneStore: d.tombstones,
        mediaFiles: mediaFiles,
        cipherProvider: () async => SyncCipher.plaintext,
        concurrency: 8,
      );

  Future<void> putLocal(String type, String name, List<int> bytes) async {
    final f = File(p.join(root.path, type, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
  }

  test('realPath 非 null 时确实走文件直通分支', () {
    expect(mediaFiles.realPath('image', 'a.jpg'), isNotNull);
    expect(FakeRemoteBackend().supportsFileObjects, isTrue);
  });

  test('push 把本地媒体经文件直通传到远端，字节一致', () async {
    final payload = List<int>.generate(4096, (i) => i % 256);
    await putLocal('image', 'a.jpg', payload);
    final backend = FakeRemoteBackend();
    final diary = buildDiary(id: 'd1', images: const ['a.jpg']);

    await engineOn(backend, FakeDiaryStore([diary])).push();

    final remote = backend.objects['media/image/a.jpg'];
    expect(remote, isNotNull);
    expect(remote, equals(Uint8List.fromList(payload)));
  });

  test('pull 把远端媒体经文件直通落到本地，字节一致', () async {
    final payload = List<int>.generate(8192, (i) => (i * 7) % 256);
    final remote = FakeRemoteBackend();
    final source = Directory(p.join(root.path, 'src'));
    await source.create(recursive: true);
    await putLocal('image', 'b.jpg', payload);
    await engineOn(
      remote,
      FakeDiaryStore([buildDiary(id: 'd2', images: const ['b.jpg'])]),
    ).push();
    // 清掉本地那份，强制走下载。
    await File(p.join(root.path, 'image', 'b.jpg')).delete();

    await engineOn(remote, FakeDiaryStore(const [])).pull();

    final local = File(p.join(root.path, 'image', 'b.jpg'));
    expect(await local.exists(), isTrue);
    expect(await local.readAsBytes(), equals(Uint8List.fromList(payload)));
  });

  test('远端是 0 字节对象时不落盘，留给下次重试', () async {
    final backend = FakeRemoteBackend();
    await engineOn(
      backend,
      FakeDiaryStore([buildDiary(id: 'd3', images: const ['c.jpg'])]),
    ).push();
    // 模拟「流式 PUT 中途断网，服务端留下 0 字节对象」。
    await putLocal('image', 'c.jpg', const [1, 2, 3]);
    backend.objects['media/image/c.jpg'] = Uint8List(0);
    await File(p.join(root.path, 'image', 'c.jpg')).delete();

    await engineOn(backend, FakeDiaryStore(const [])).pull();

    expect(
      await File(p.join(root.path, 'image', 'c.jpg')).exists(),
      isFalse,
      reason: '0 字节对象不能落成本地媒体——exists() 之后就再也不会重下了',
    );
  });

  test('并发下载不会因临时文件撞名而互相踩', () async {
    final names = [for (var i = 0; i < 8; i++) 'm$i.jpg'];
    final payloads = {
      for (final n in names)
        n: List<int>.generate(2048, (i) => (n.hashCode + i) % 256),
    };
    for (final n in names) {
      await putLocal('image', n, payloads[n]!);
    }
    final backend = FakeRemoteBackend();
    await engineOn(
      backend,
      FakeDiaryStore([buildDiary(id: 'd4', images: names)]),
    ).push();
    for (final n in names) {
      await File(p.join(root.path, 'image', n)).delete();
    }

    await engineOn(backend, FakeDiaryStore(const [])).pull();

    for (final n in names) {
      final local = File(p.join(root.path, 'image', n));
      expect(await local.exists(), isTrue, reason: '$n 应当被下载');
      expect(
        await local.readAsBytes(),
        equals(Uint8List.fromList(payloads[n]!)),
        reason: '$n 的内容不能被别的并发任务写串',
      );
    }
  });

  test('同步临时目录用完即清，不留全尺寸残留', () async {
    await putLocal('image', 'e.jpg', List<int>.filled(1024, 9));
    final backend = FakeRemoteBackend();
    await engineOn(
      backend,
      FakeDiaryStore([buildDiary(id: 'd5', images: const ['e.jpg'])]),
    ).push();

    final tempDir = Directory(p.join(cacheRoot.path, 'sync-media'));
    if (await tempDir.exists()) {
      expect(await tempDir.list().isEmpty, isTrue);
    }
  });
}
