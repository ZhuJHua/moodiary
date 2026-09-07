import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fast_tokenizer/fast_tokenizer.dart' show TokenizeResult;
import 'package:fast_tokenizer/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sqlite_vec/moodiary_sqlite_vec.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

Future<TokenizeResult> fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

final class FakeEmbedder implements SemanticEmbedder {
  @override
  Future<void> dispose() async {}

  static const markers = ['旅行', '工作', '美食', '天气'];

  int embeddedPassages = 0;

  @override
  bool ready = true;

  @override
  int dim = markers.length;

  static Float32List vecOf(String text) {
    final v = Float32List(markers.length);
    for (var i = 0; i < markers.length; i++) {
      v[i] = text.contains(markers[i]) ? 1.0 : 0.05 * (i + 1);
    }
    final norm = sqrt(v.fold<double>(0, (acc, x) => acc + x * x));
    for (var i = 0; i < v.length; i++) {
      v[i] /= norm;
    }
    return v;
  }

  @override
  Future<List<Float32List>> embedPassages(List<String> texts) async {
    embeddedPassages += texts.length;
    return [for (final t in texts) vecOf(t)];
  }

  @override
  Future<Float32List> embedQuery(String text) async => vecOf(text);
}

Diary makeDiary(String id, String text, {bool show = true, String? title}) =>
    Diary(
      id: id,
      categoryId: null,
      title: title ?? '',
      content: '{}',
      contentText: text,
      time: DateTime.utc(2026, 1, 1),
      lastModified: DateTime.utc(2026, 1, 1),
      show: show,
      mood: .neutral,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: 'tiptap',
    );

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;
  late FakeEmbedder embedder;
  late EmbedIndexService index;

  setUpAll(() {
    loadSqliteVec();
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() async {
    MoodiaryKVs.embeddingIndexStale.remove();
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    installFakeFastTokenizer(fakeTokenize);
    repo = DiaryRepository(db);
    embedder = FakeEmbedder();
    index = EmbedIndexService(db, embedder);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> queueCount() async =>
      (await db.select(db.embedQueue).get()).length;

  Future<int> chunkCount() async =>
      (await db.select(db.diaryChunks).get()).length;

  Future<int> vecCount() async =>
      (await db
              .customSelect('SELECT COUNT(*) AS c FROM vec_diary_chunks')
              .getSingle())
          .read<int>('c');

  test('写入入队，排空建块与向量，二次排空幂等跳过', () async {
    await repo.insertADiary(makeDiary('d1', '今天去旅行了', title: '出门'));
    await repo.insertADiary(makeDiary('d2', '今天在工作'));
    expect(await queueCount(), 2);

    expect(await index.drain(), 2);
    expect(await queueCount(), 0);
    expect(await chunkCount(), 3);
    expect(await vecCount(), 3);

    final embedded = embedder.embeddedPassages;
    await repo.updateADiary(newDiary: makeDiary('d1', '今天去旅行了', title: '出门'));
    expect(await index.drain(), 1);
    expect(embedder.embeddedPassages, embedded);
  });

  test('语义检索按含义命中，回收站被排除', () async {
    await repo.insertADiary(makeDiary('travel', '这次旅行很开心'));
    await repo.insertADiary(makeDiary('work', '工作压力很大'));
    await repo.insertADiary(makeDiary('hidden', '另一场旅行', show: false));
    await index.drain();

    final hits = await index.search('旅行', limit: 2);
    expect(hits.first.diaryId, 'travel');
    expect(hits.map((h) => h.diaryId), isNot(contains('hidden')));

    final workHits = await index.search('工作', limit: 1);
    expect(workHits.single.diaryId, 'work');
  });

  test('内容变化触发重嵌，摘录偏移指向命中分块', () async {
    // 400 字符是分块字数上限
    final firstParagraph = '工作${'。' * 400}';
    await repo.insertADiary(makeDiary('d1', '$firstParagraph\n\n第二段说的是旅行的事'));
    await index.drain();
    final hit = (await index.search('旅行', limit: 1)).single;
    expect(hit.diaryId, 'd1');
    expect(hit.startOff, greaterThan(0));
    final diary = (await repo.getDiaryByBusinessId('d1'))!;
    expect(
      diary.contentText.substring(hit.startOff, hit.startOff + hit.len),
      contains('旅行'),
    );
  });

  test('硬删除由排空回收孤儿分块与向量', () async {
    await repo.insertADiary(makeDiary('d1', '旅行日记'));
    await index.drain();
    expect(await chunkCount(), 1);

    await repo.deleteDiariesByIds(['d1']);
    expect(await queueCount(), 1);
    await index.drain();
    expect(await chunkCount(), 0);
    expect(await vecCount(), 0);
    expect(await index.search('旅行'), isEmpty);
  });

  test('rebuildAll 全量重灌', () async {
    await repo.insertADiary(makeDiary('d1', '旅行'));
    await repo.insertADiary(makeDiary('d2', '美食'));
    await index.drain();
    final before = embedder.embeddedPassages;

    expect(await index.rebuildAll(), 2);
    expect(embedder.embeddedPassages, greaterThan(before));
    expect(await vecCount(), 2);
    expect((await index.search('美食', limit: 1)).single.diaryId, 'd2');
    expect(MoodiaryKVs.embeddingIndexStale.get(), isFalse);
  });

  test('未启用时 drain/search 均为 no-op', () async {
    embedder.ready = false;
    await repo.insertADiary(makeDiary('d1', '旅行'));
    expect(await index.drain(), 0);
    expect(await queueCount(), 1);
    expect(await index.search('旅行'), isEmpty);
  });
}
