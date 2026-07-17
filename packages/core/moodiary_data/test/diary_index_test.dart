// 真库集成测试:在宿主机直接开 isar_plus 原生库,验证 posting-list 倒排的正确性。
//
// 需要 libisar_plus 动态库(macOS 可从 GitHub release 的 isar_plus_core.xcframework.zip
// 提取静态库后转 dylib:`lipo -thin arm64` + `clang -dynamiclib -Wl,-all_load`),然后:
//
//   ISAR_TEST_DYLIB=/path/to/libisar_plus.dylib fvm flutter test test/diary_index_test.dart
//
// 未设置环境变量时整组跳过,不影响常规 CI。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart' show TokenizeResult;
import 'package:moodiary_utils/moodiary_utils.dart';

/// 替身分词:cut = 空白切词(保留重复,词频=出现次数),cutForSearch = 同词表
/// (宿主测试无 Rust FFI)。
Future<TokenizeResult> fakeTokenize(String text) async {
  final words =
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

class _MemoryKV extends IKVStorage {
  final Map<String, Object> _store = {};

  @override
  Future<void> init() async {}

  @override
  T? get<T extends Object>(String key) => _store[key] as T?;

  @override
  Future<void> set<T extends Object>(String key, T value) async {
    _store[key] = value;
    await super.set(key, value);
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
    await super.remove(key);
  }

  @override
  Future<void> clear() async => _store.clear();
}

Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  List<String> linkTo = const [],
}) {
  final doc = content ??
      jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'text',
                'text': text,
              },
              for (final target in linkTo)
                {
                  'type': 'diaryLink',
                  'attrs': {'id': target},
                },
            ],
          },
        ],
      });
  return Diary(
    id: id,
    title: title ?? 'title-$id',
    content: doc,
    contentText: text,
    time: DateTime(2026, 1, 1),
    lastModified: DateTime(2026, 1, 1),
    show: true,
    mood: 0.5,
    weather: const [],
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const [],
    position: const [],
    type: 'tiptap',
  );
}

int searchKey(TokenSource source, String token) =>
    fastHash('${source.name}:$token');

void main() {
  final dylib = Platform.environment['ISAR_TEST_DYLIB'];
  if (dylib == null || dylib.isEmpty) {
    test(
      'diary posting index (skipped)',
      () {},
      skip: '需要 ISAR_TEST_DYLIB 指向 libisar_plus 动态库,见文件头注释',
    );
    return;
  }

  late Directory dir;
  late Isar isar;
  late DiaryRepository repo;

  setUpAll(() async {
    await Isar.initialize(dylib);
    getIt.registerSingleton<IKVStorage>(_MemoryKV());
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('moodiary_index_test');
    isar = Isar.open(
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
      inspector: false,
    );
    repo = DiaryRepository.forTesting(isar, tokenizer: fakeTokenize);
  });

  tearDown(() {
    isar.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<Diary>> search(String word) =>
      repo.searchDiaries(cutTokens: [word], cutForSearchTokens: const []);

  test('插入后可按分词搜索到,快照与 posting 落库', () async {
    final diary = makeDiary('d1', '苹果 香蕉');
    await repo.insertADiary(diary);

    final hits = await search('苹果');
    expect(hits.map((d) => d.id), ['d1']);

    final posting =
        await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果'));
    expect(posting?.diaryIsarIds, [diary.isarId]);
    final snapshot = await isar.diaryIndexSnapshots.getAsync(diary.isarId);
    expect(snapshot?.cutTokens, containsAll(['苹果', '香蕉']));
  });

  test('同 id 重复插入(云 pull / 导入)不产生重复计权', () async {
    final diary = makeDiary('d1', '苹果 香蕉');
    await repo.insertADiary(diary);
    await repo.insertADiary(diary);
    await repo.insertADiary(diary);

    final posting =
        await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果'));
    expect(posting?.diaryIsarIds, [diary.isarId]);
  });

  test('inline 更新:旧词摘除、新词可搜,空 posting 行回收', () async {
    final v1 = makeDiary('d1', '苹果');
    await repo.insertADiary(v1);
    final v2 = makeDiary('d1', '橘子');
    await repo.updateADiary(newDiary: v2);

    expect(await search('苹果'), isEmpty);
    expect((await search('橘子')).map((d) => d.id), ['d1']);
    expect(
      await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果')),
      isNull,
    );
  });

  test('defer 更新只入队,drain 后索引生效', () async {
    await repo.insertADiary(makeDiary('d1', '苹果'));
    await repo.updateADiary(
      newDiary: makeDiary('d1', '橘子'),
      index: IndexMode.defer,
    );

    // 排空前:索引仍是旧内容
    expect((await search('苹果')).map((d) => d.id), ['d1']);
    expect(await search('橘子'), isEmpty);
    expect(isar.reindexQueues.where().count(), 1);

    final drained = await repo.drainReindexQueue();
    expect(drained, 1);
    expect(isar.reindexQueues.where().count(), 0);
    expect(await search('苹果'), isEmpty);
    expect((await search('橘子')).map((d) => d.id), ['d1']);
  });

  test('skip 更新不入队、索引不动', () async {
    await repo.insertADiary(makeDiary('d1', '苹果'));
    await repo.updateADiary(
      newDiary: makeDiary('d1', '苹果'),
      index: IndexMode.skip,
    );
    expect(isar.reindexQueues.where().count(), 0);
    expect((await search('苹果')).map((d) => d.id), ['d1']);
  });

  test('双链:建立、反查、移除后 posting 行回收', () async {
    final target = makeDiary('target', '目标');
    await repo.insertADiary(target);
    await repo.insertADiary(makeDiary('src', '来源', linkTo: ['target']));

    final backlinks = await repo.getBacklinks('target');
    expect(backlinks.map((d) => d.id), ['src']);

    await repo.updateADiary(newDiary: makeDiary('src', '来源'));
    expect(await repo.getBacklinks('target'), isEmpty);
    expect(await isar.linkPostings.getAsync(fastHash('target')), isNull);
  });

  test('软删清空该篇全部倒排与快照', () async {
    final diary = makeDiary('d1', '苹果', linkTo: ['other']);
    await repo.insertADiary(diary);
    await repo.deleteADiary(diary.isarId);

    expect(await search('苹果'), isEmpty);
    expect(await isar.diaryIndexSnapshots.getAsync(diary.isarId), isNull);
    expect(await isar.linkPostings.getAsync(fastHash('other')), isNull);
  });

  test('硬删同软删,且日记行移除', () async {
    final diary = makeDiary('d1', '苹果');
    await repo.insertADiary(diary);
    await repo.deleteDiariesByIsarIds([diary.isarId]);

    expect(await search('苹果'), isEmpty);
    expect(await isar.diarys.getAsync(diary.isarId), isNull);
    expect(await isar.diaryIndexSnapshots.getAsync(diary.isarId), isNull);
  });

  test('残留队列指向已删日记:drain 清队不崩溃', () async {
    await isar.writeAsync(
      (isar) => isar.reindexQueues.put(const ReindexQueue(diaryIsarId: 42)),
    );
    expect(await repo.drainReindexQueue(), 1);
    expect(isar.reindexQueues.where().count(), 0);
  });

  test('rebuildAllIndexes 全量重建幂等,并置位回填标记', () async {
    await repo.insertADiary(makeDiary('d1', '苹果 香蕉', title: '重建标题'));
    await repo.insertADiary(makeDiary('d2', '苹果', linkTo: ['d1']));

    // 人为破坏倒排,验证重建可恢复
    await isar.writeAsync((isar) {
      isar.searchPostings.clear();
      isar.linkPostings.clear();
      isar.diaryIndexSnapshots.clear();
    });
    expect(await search('苹果'), isEmpty);

    expect(await repo.rebuildAllIndexes(), 2);
    expect((await search('苹果')).map((d) => d.id), containsAll(['d1', 'd2']));
    expect((await repo.getBacklinks('d1')).map((d) => d.id), ['d2']);
    // 重建路径的标题也进倒排
    expect(
      (await repo.searchDiaries(
        cutTokens: const [],
        cutForSearchTokens: ['重建标题'],
      )).map((d) => d.id),
      ['d1'],
    );
    expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);

    // 重复重建不累积
    await repo.rebuildAllIndexes();
    final posting =
        await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果'));
    expect(posting?.diaryIsarIds, hasLength(2));
  });

  test('insertDiaries 批量:共享词聚合、批内同 id 取末条、与逐篇结果等价', () async {
    await repo.insertDiaries([
      makeDiary('d1', '苹果 香蕉', title: '批量标题'),
      makeDiary('d2', '苹果 橘子', linkTo: ['d1']),
      makeDiary('d3', '苹果'),
      // 批内同 id 重复:以最后一条为准
      makeDiary('d3', '梨'),
    ]);

    // 批量路径的标题也进倒排
    expect(
      (await repo.searchDiaries(
        cutTokens: const [],
        cutForSearchTokens: ['批量标题'],
      )).map((d) => d.id),
      ['d1'],
    );

    final apple =
        await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果'));
    expect(apple?.diaryIsarIds.toSet(), {
      fastHash('d1'),
      fastHash('d2'),
    });
    expect((await search('梨')).map((d) => d.id), ['d3']);
    expect(await search('苹果'), hasLength(2));
    expect((await repo.getBacklinks('d1')).map((d) => d.id), ['d2']);

    // 批量后再逐篇覆盖,与单篇路径互操作
    await repo.insertADiary(makeDiary('d2', '香蕉'));
    expect((await search('苹果')).map((d) => d.id), ['d1']);
    expect(await repo.getBacklinks('d1'), isEmpty);
  });

  test('BM25:词频饱和加分——同词出现多次排前,但有界', () async {
    await repo.insertADiary(makeDiary('d1', '苹果 香蕉 桃子 梨'));
    await repo.insertADiary(makeDiary('d3', '苹果 苹果 苹果 桃子'));

    final hits = await search('苹果');
    expect(hits.map((d) => d.id), ['d3', 'd1']);
  });

  test('BM25:IDF——命中罕见词的日记排在只命中常见词的前面', () async {
    for (var i = 0; i < 6; i++) {
      await repo.insertADiary(makeDiary('common-$i', '常见 内容 $i'));
    }
    await repo.insertADiary(makeDiary('rare', '罕见 内容'));

    final hits = await repo.searchDiaries(
      cutTokens: ['常见', '罕见'],
      cutForSearchTokens: const [],
    );
    expect(hits.first.id, 'rare');
  });

  test('标题进倒排:标题命中可搜且权重高于正文命中', () async {
    await repo.insertADiary(makeDiary('body', '苹果 内容 其他'));
    await repo.insertADiary(makeDiary('titled', '别的 内容', title: '苹果'));

    final hits = await repo.searchDiaries(
      cutTokens: ['苹果'],
      cutForSearchTokens: ['苹果'],
    );
    expect(hits.map((d) => d.id), ['titled', 'body']);
  });

  test('标题变更走 defer,drain 后新标题可搜、旧标题摘除', () async {
    await repo.insertADiary(makeDiary('d1', '正文', title: '旧标题'));
    await repo.updateADiary(
      newDiary: makeDiary('d1', '正文', title: '新标题'),
      index: IndexMode.defer,
    );
    await repo.drainReindexQueue();

    Future<List<Diary>> byTitle(String w) =>
        repo.searchDiaries(cutTokens: const [], cutForSearchTokens: [w]);
    expect((await byTitle('新标题')).map((d) => d.id), ['d1']);
    expect(await byTitle('旧标题'), isEmpty);
  });

  test('BM25:长度归一——同词频下短文排前', () async {
    final filler = List.generate(120, (i) => '填充$i').join(' ');
    await repo.insertADiary(makeDiary('long', '苹果 $filler'));
    await repo.insertADiary(makeDiary('short', '苹果 一点 内容'));

    final hits = await search('苹果');
    expect(hits.map((d) => d.id), ['short', 'long']);
  });

  test('墓碑路径:tombstoneDiaryForSync 删行 + 清索引 + 落墓碑行', () async {
    final d1 = makeDiary('d1', '苹果', title: '标题一');
    await repo.insertADiary(d1);
    // 同步引擎的 tombstone 路径:行硬删,删除事实落 SyncTombstone 表
    final tombstone = await repo.tombstoneDiaryForSync(d1);
    expect(tombstone.key, 'd:d1');
    expect(await search('苹果'), isEmpty);
    expect(await isar.diarys.getAsync(d1.isarId), isNull);
    expect(await isar.diaryIndexSnapshots.getAsync(d1.isarId), isNull);
    expect((await isar.searchStats.getAsync(0))?.docCount, 0);
    expect(await isar.syncTombstones.getAsync(tombstone.isarId), isNotNull);

    // 重新插入同 id(pull 复活)→ 墓碑行连带清除
    await repo.insertADiary(d1);
    expect(await isar.syncTombstones.getAsync(tombstone.isarId), isNull);
    expect((await search('苹果')).map((d) => d.id), ['d1']);
  });

  test('SearchStats 随增删改与重建保持一致', () async {
    final a = makeDiary('a', '一二三');
    final b = makeDiary('b', '四五六七');
    // 纯媒体日记(正文为空,只有标题):计入 docCount,不计入 avgdl 分母
    final m = makeDiary('m', '', title: '只有标题');
    await repo.insertDiaries([a, b, m]);
    var stats = await isar.searchStats.getAsync(0);
    expect(stats?.docCount, 3);
    expect(stats?.contentDocCount, 2);
    expect(
      stats?.totalContentChars,
      a.contentText.length + b.contentText.length,
    );

    final a2 = makeDiary('a', '一二三四五六');
    await repo.updateADiary(newDiary: a2);
    stats = await isar.searchStats.getAsync(0);
    expect(stats?.docCount, 3);
    expect(stats?.contentDocCount, 2);
    expect(
      stats?.totalContentChars,
      a2.contentText.length + b.contentText.length,
    );

    await repo.deleteDiariesByIsarIds([a2.isarId]);
    stats = await isar.searchStats.getAsync(0);
    expect(stats?.docCount, 2);
    expect(stats?.contentDocCount, 1);
    expect(stats?.totalContentChars, b.contentText.length);

    await repo.rebuildAllIndexes();
    stats = await isar.searchStats.getAsync(0);
    expect(stats?.docCount, 2);
    expect(stats?.contentDocCount, 1);
    expect(stats?.totalContentChars, b.contentText.length);
  });

  test('getDiaryByBusinessId 走 fastHash 主键', () async {
    final diary = makeDiary('biz-id-001', '内容');
    await repo.insertADiary(diary);
    expect((await repo.getDiaryByBusinessId('biz-id-001'))?.id, 'biz-id-001');
    expect(await repo.getDiaryByBusinessId('missing'), isNull);
  });
}
