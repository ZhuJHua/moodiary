// 引擎搬迁压测（宿主）：灌 N 篇旧 Isar 日记 → migrate → 抽查典型查询耗时。
// 与 docs/db-benchmark.md 的旧引擎数字对照用；分词是空白切词替身（宿主无 FRB），
// 真机上 jieba 单篇毫秒级，量级判断不受影响。
//
//   ISAR_TEST_DYLIB=... MOODIARY_BENCH_N=20000 fvm flutter test \
//     test/engine_migration_benchmark_test.dart
//
// 未设置 ISAR_TEST_DYLIB 时整组跳过；N 缺省 2000（CI 可承受）。
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;
import 'package:moodiary_rust/foundation.dart' show TokenizeResult;
import 'package:moodiary_rust/testing.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

Future<TokenizeResult> fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

const _vocab = [
  '苹果', '香蕉', '天气', '散步', '加班', '心情', '电影', '朋友', '旅行', '咖啡', //
  '地铁', '晚饭', '读书', '跑步', '海边', '日落', '会议', '代码', '猫咪', '音乐',
];

String _sentence(Random rng, int words) =>
    [for (var i = 0; i < words; i++) _vocab[rng.nextInt(_vocab.length)]]
        .join(' ');

void main() {
  final dylib = Platform.environment['ISAR_TEST_DYLIB'];
  if (dylib == null || dylib.isEmpty) {
    test(
      'engine migration benchmark (skipped)',
      () {},
      skip: '需要 ISAR_TEST_DYLIB，见文件头',
    );
    return;
  }
  final n =
      int.tryParse(Platform.environment['MOODIARY_BENCH_N'] ?? '') ?? 2000;

  setUpAll(() async {
    await Isar.initialize(dylib);
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  test('搬迁 $n 篇 + 典型查询', () async {
    final dir = Directory.systemTemp.createTempSync('engine_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    installFakeRustLib(fakeTokenize);

    // —— 种子旧库 —— //
    final rng = Random(42);
    final seedWatch = Stopwatch()..start();
    final isar = Isar.open(
      schemas: legacy.moodiarySchemas,
      directory: dir.path,
      inspector: false,
    );
    const chunk = 500;
    for (var start = 0; start < n; start += chunk) {
      final end = min(start + chunk, n);
      isar.write((tx) {
        tx.diarys.putAll([
          for (var i = start; i < end; i++)
            legacy.Diary(
              id: 'bench-$i',
              title: _sentence(rng, 3),
              content:
                  '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"${_sentence(rng, 120)}"}]}]}',
              contentText: _sentence(rng, 120),
              time: DateTime.utc(2024).add(Duration(minutes: i)),
              lastModified: DateTime.utc(2024).add(Duration(minutes: i)),
              show: true,
              mood: rng.nextDouble(),
              weather: const [],
              imageName: const [],
              audioName: const [],
              videoName: const [],
              tags: const [],
              position: const [],
              type: 'tiptap',
            ),
        ]);
      });
    }
    isar.close();
    seedWatch.stop();

    // —— 搬迁（文件库，贴近真机形态）—— //
    final db = MoodiaryDatabase.forTesting(
      NativeDatabase(
        File('${dir.path}/bench.db'),
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
          raw.execute('PRAGMA synchronous = NORMAL');
          raw.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    addTearDown(db.close);
    final repo = DiaryRepository.forTesting(db);
    final report = await EngineMigrationService.migrate(
      database: db,
      diaryRepository: repo,
      categoryRepository: CategoryRepository.forTesting(db),
      fontRepository: FontRepository.forTesting(db),
      mediaInfoRepository: MediaInfoRepository.forTesting(db),
      tombstoneRepository: TombstoneRepository.forTesting(db),
      legacyDir: dir.path,
    );
    expect(report.diaries, n);

    Future<Duration> timed(Future<void> Function() run) async {
      final w = Stopwatch()..start();
      await run();
      return w.elapsed;
    }

    final page = await timed(() async {
      final rows = await repo.getDiaryByCategory(limit: 20, offset: 0);
      expect(rows, hasLength(20));
    });
    final deepPage = await timed(
      () => repo.getDiaryByCategory(limit: 20, offset: max(0, n - 20)),
    );
    late List<dynamic> hits;
    final search = await timed(() async {
      hits = await repo.searchDiaries(
        cutTokens: const ['苹果'],
        cutForSearchTokens: const [],
        limit: 50,
      );
    });
    final monthCount = await timed(() => repo.diaryCountByMonth());
    final dbSize = File('${dir.path}/bench.db').lengthSync();

    // ignore: avoid_print
    print(
      '[bench n=$n] seed=${seedWatch.elapsed.inMilliseconds}ms '
      'migrate=${report.elapsed.inMilliseconds}ms '
      'page@0=${page.inMilliseconds}ms page@${max(0, n - 20)}=${deepPage.inMilliseconds}ms '
      'search(top50, hits=${hits.length})=${search.inMilliseconds}ms '
      'monthCount=${monthCount.inMilliseconds}ms '
      'db=${(dbSize / 1024 / 1024).toStringAsFixed(1)}MiB',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
