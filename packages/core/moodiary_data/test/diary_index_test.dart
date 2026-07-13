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

/// 替身分词:cut = 空白切词去重,cutForSearch = 同词表(宿主测试无 Rust FFI)。
Future<TokenizeResult> fakeTokenize(String text) async {
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
    title: 'title-$id',
    content: doc,
    contentText: text,
    time: DateTime(2026, 1, 1),
    lastModified: DateTime(2026, 1, 1),
    show: true,
    deleted: false,
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
        LinkPostingSchema,
        DiaryIndexSnapshotSchema,
        ReindexQueueSchema,
        CategorySchema,
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
    await repo.insertADiary(makeDiary('d1', '苹果 香蕉'));
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
    expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);

    // 重复重建不累积
    await repo.rebuildAllIndexes();
    final posting =
        await isar.searchPostings.getAsync(searchKey(TokenSource.cut, '苹果'));
    expect(posting?.diaryIsarIds, hasLength(2));
  });

  test('insertDiaries 批量:共享词聚合、批内同 id 取末条、与逐篇结果等价', () async {
    await repo.insertDiaries([
      makeDiary('d1', '苹果 香蕉'),
      makeDiary('d2', '苹果 橘子', linkTo: ['d1']),
      makeDiary('d3', '苹果'),
      // 批内同 id 重复:以最后一条为准
      makeDiary('d3', '梨'),
    ]);

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

  test('getDiaryByBusinessId 走 fastHash 主键', () async {
    final diary = makeDiary('biz-id-001', '内容');
    await repo.insertADiary(diary);
    expect((await repo.getDiaryByBusinessId('biz-id-001'))?.id, 'biz-id-001');
    expect(await repo.getDiaryByBusinessId('missing'), isNull);
  });
}
