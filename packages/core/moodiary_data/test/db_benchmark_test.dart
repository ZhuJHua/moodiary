// 数据库整体基准:对真实 DiaryRepository(posting-list 倒排)在 1k/5k/20k 篇规模下
// 测量各热点场景。结果见 docs/db-benchmark.md。
//
// 平时不跑(CI 自动跳过),需要两个环境变量同时打开:
//
//   ISAR_TEST_DYLIB=/path/to/libisar_plus.dylib RUN_DB_BENCH=1 \
//     fvm flutter test test/db_benchmark_test.dart
//
// dylib 获取方式见 diary_index_test.dart 文件头。输出为 `BENCH|...` 结构化行。
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart' show TokenizeResult;
import 'package:moodiary_rust/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

const _vocab = 6000;
final _rng = Random(42);

String _tok(int i) => 'tok${i.toString().padLeft(5, '0')}词';

/// 偏斜采样(少数高频 + 长尾),近似真实词频。
int _zipf() {
  final r = _rng.nextDouble();
  return (r * r * _vocab).floor().clamp(0, _vocab - 1);
}

/// 每篇 ~135 个采样词(去重后 ~110),经 cut+cutForSearch 双源 ≈ 220 个 posting 键,
/// 对应约 2000 字日记的分词量级。
String _contentText() => List.generate(135, (_) => _tok(_zipf())).join(' ');

Future<TokenizeResult> _fakeTokenize(String text) async {
  final words = text
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toSet()
      .toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

class _MemoryKV extends IKVStorage {
  final Map<String, Object> _store = {};
  @override
  Future<void> init() async {}
  @override
  T? get<T extends Object>(String key) => _store[key] as T?;
  @override
  void set<T extends Object>(String key, T value) {
    _store[key] = value;
    super.set(key, value);
  }

  @override
  void clear() => _store.clear();
}

Diary _diary(int i, int scale, {String? text}) {
  final contentText = text ?? _contentText();
  final linkTargets = [
    'bench-${_rng.nextInt(scale)}',
    'bench-${_rng.nextInt(scale)}',
  ];
  return Diary(
    id: 'bench-$i',
    categoryId: 'cat${i % 8}',
    title: 'title-$i',
    content: jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': contentText},
            for (final t in linkTargets)
              {
                'type': 'diaryLink',
                'attrs': {'id': t},
              },
          ],
        },
      ],
    }),
    contentText: contentText,
    time: DateTime(2024, 1, 1).add(Duration(minutes: i * 37)),
    lastModified: DateTime(2025, 1, 1).add(Duration(minutes: i)),
    show: true,
    mood: 0.5,
    weather: const ['sunny', '25', 'icon1'],
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const ['tag1'],
    position: const [],
    type: 'tiptap',
  );
}

Future<({double median, double p90})> _bench(
  int reps,
  Future<void> Function() f,
) async {
  final samples = <double>[];
  for (var i = 0; i < reps; i++) {
    final sw = Stopwatch()..start();
    await f();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  samples.sort();
  return (
    median: samples[samples.length ~/ 2],
    p90: samples[(samples.length * 0.9).floor().clamp(0, samples.length - 1)],
  );
}

void _report(int scale, String scenario, double median, [double? p90]) {
  // ignore: avoid_print
  print(
    'BENCH|scale=$scale|$scenario|median=${median.toStringAsFixed(2)}'
    '${p90 == null ? '' : '|p90=${p90.toStringAsFixed(2)}'}',
  );
}

void main() {
  final dylib = Platform.environment['ISAR_TEST_DYLIB'];
  final enabled = Platform.environment['RUN_DB_BENCH'] == '1';
  if (dylib == null || dylib.isEmpty || !enabled) {
    test(
      'db benchmark (skipped)',
      () {},
      skip: '需要 ISAR_TEST_DYLIB 与 RUN_DB_BENCH=1,见文件头注释',
    );
    return;
  }

  setUpAll(() async {
    await Isar.initialize(dylib);
    getIt.registerSingleton<IKVStorage>(_MemoryKV());
  });

  for (final scale in [1000, 5000, 20000]) {
    test('scale $scale', () async {
      final dir = Directory.systemTemp.createTempSync('moodiary_bench_$scale');
      final isar = Isar.open(
        schemas: [
          DiarySchema,
          SearchPostingSchema,
          SearchStatsSchema,
          LinkPostingSchema,
          DiaryIndexSnapshotSchema,
          ReindexQueueSchema,
          CategorySchema,
          SyncTombstoneSchema,
        ],
        directory: dir.path,
        maxSizeMiB: 4096,
        inspector: false,
      );
      installFakeRustLib(_fakeTokenize);
      final repo = DiaryRepository.forTesting(isar);

      // ---- 场景 0:批量导入(= JSON 恢复 / insertDiaries 路径) ----
      final seedSw = Stopwatch()..start();
      for (var i = 0; i < scale; i += 500) {
        await repo.insertDiaries([
          for (var j = i; j < min(i + 500, scale); j++) _diary(j, scale),
        ]);
      }
      seedSw.stop();
      _report(scale, 'import_batch_total', seedSw.elapsedMilliseconds * 1.0);

      final targets = [for (var i = 0; i < 30; i++) _rng.nextInt(scale)];

      // ---- 场景 1:自动保存(defer,编辑期热路径) ----
      var seq = 0;
      final autosave = await _bench(30, () async {
        final i = targets[seq++ % targets.length];
        await repo.updateADiary(newDiary: _diary(i, scale), index: .defer);
      });
      _report(scale, 'autosave_defer', autosave.median, autosave.p90);

      // ---- 场景 2:关闭编辑器重索引(单篇) ----
      final reindex = await _bench(12, () async {
        final i = targets[seq++ % targets.length];
        await repo.reindexDiary(fastHash('bench-$i'));
      });
      _report(scale, 'reindex_one', reindex.median, reindex.p90);

      // ---- 场景 3:启动恢复排空(队列剩余) ----
      final drainSw = Stopwatch()..start();
      final drained = await repo.drainReindexQueue();
      drainSw.stop();
      _report(
        scale,
        'drain_queue_${drained}pending',
        drainSw.elapsedMilliseconds * 1.0,
      );

      // ---- 场景 4:搜索(中低频 3 词 / 含高频词) ----
      final mid = await _bench(15, () async {
        await repo.searchDiaries(
          cutTokens: [_tok(1200), _tok(2500), _tok(4500)],
          cutForSearchTokens: [_tok(1200), _tok(2500), _tok(4500)],
        );
      });
      _report(scale, 'search_3words_mid', mid.median, mid.p90);

      final hot = await _bench(10, () async {
        await repo.searchDiaries(
          cutTokens: [_tok(1), _tok(1200), _tok(2500)],
          cutForSearchTokens: [_tok(1), _tok(1200), _tok(2500)],
        );
      });
      _report(scale, 'search_3words_hot', hot.median, hot.p90);

      // ---- 场景 5:反链 ----
      final backlinks = await _bench(15, () async {
        await repo.getBacklinks('bench-${_rng.nextInt(scale)}');
      });
      _report(scale, 'backlinks', backlinks.median, backlinks.p90);

      // ---- 场景 6:首页分页 / 业务 id ----
      final home = await _bench(15, () async {
        await repo.getDiaryByCategory(offset: 0, limit: 40);
      });
      _report(scale, 'home_page_40', home.median, home.p90);

      final byId = await _bench(15, () async {
        await repo.getDiaryByBusinessId('bench-${scale ~/ 2}');
      });
      _report(scale, 'by_business_id', byId.median, byId.p90);

      // ---- 场景 7:单篇插入(满库时的最坏单篇成本) ----
      var newSeq = 0;
      final insertOne = await _bench(20, () async {
        await repo.insertADiary(_diary(scale + newSeq++, scale));
      });
      _report(scale, 'insert_single', insertOne.median, insertOne.p90);

      // ---- 场景 8:批量硬删 100 篇(tombstone 清除路径) ----
      final delIds = [
        for (var i = 0; i < 100; i++) fastHash('bench-${scale + i}'),
      ];
      // 先补齐 100 篇(上面只插了 20 篇新的)
      await repo.insertDiaries([
        for (var i = newSeq; i < 100; i++) _diary(scale + i, scale),
      ]);
      final delSw = Stopwatch()..start();
      await repo.deleteDiariesByIsarIds(delIds);
      delSw.stop();
      _report(scale, 'hard_delete_100', delSw.elapsedMilliseconds * 1.0);

      // ---- 场景 9:全量重建(数据修复路径) ----
      final rebuildSw = Stopwatch()..start();
      await repo.rebuildAllIndexes();
      rebuildSw.stop();
      _report(scale, 'rebuild_all_total', rebuildSw.elapsedMilliseconds * 1.0);

      // ---- 磁盘占用 ----
      const mb = 1024 * 1024;
      _report(
        scale,
        'size_diary_mb',
        isar.diarys.getSize(includeIndexes: true) / mb,
      );
      _report(
        scale,
        'size_search_posting_mb',
        isar.searchPostings.getSize(includeIndexes: true) / mb,
      );
      _report(
        scale,
        'size_link_posting_mb',
        isar.linkPostings.getSize(includeIndexes: true) / mb,
      );
      _report(
        scale,
        'size_snapshot_mb',
        isar.diaryIndexSnapshots.getSize(includeIndexes: true) / mb,
      );

      expect(
        (await repo.searchDiaries(
          cutTokens: [_tok(1200)],
          cutForSearchTokens: const [],
        )),
        isNotEmpty,
      );
      isar.close();
      dir.deleteSync(recursive: true);
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
