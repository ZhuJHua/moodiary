import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late PlaceRepository places;
  late DiaryRepository diaries;

  Place make(
    String id,
    String name, {
    double lat = 30.2841,
    double lon = 120.1552,
  }) => Place(
    id: id,
    name: name,
    latitude: lat,
    longitude: lon,
    lastModified: DateTime.utc(2026, 9, 5),
  );

  Future<void> insertDiary(
    String id,
    String? placeId, {
    bool show = true,
    int lastModified = 0,
  }) => db
      .into(db.diaries)
      .insert(
        DiariesCompanion.insert(
          id: id,
          title: '',
          content: '',
          contentText: '',
          time: 0,
          lastModified: lastModified,
          show: show ? 1 : 0,
          moodLevel: Value(DiaryMood.okay.score),
          type: 'tiptap',
          placeId: Value(placeId),
        ),
      );

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    places = PlaceRepository(db);
    diaries = DiaryRepository(db);
  });

  tearDown(() => db.close());

  /// broadcast 事件经微任务异步派发，断言事件/状态前先冲刷。
  Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

  test('合并：改名保留方、日记（含回收站）重指、被合并方删除并留墓碑', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));
    await places.insertAPlace(make('c', '公司', lat: 30.6));
    await insertDiary('d1', 'a');
    await insertDiary('d2', 'b', lastModified: 100);
    await insertDiary('d3', 'b', show: false);

    final record = await places.mergePlaces(
      kept: make('a', '家'),
      finalName: '家（合并）',
      removed: [make('b', '家门口', lat: 30.2842)],
      placeOrder: const ['a', 'b', 'c'],
      diaries: diaries,
    );

    // 凭据内容
    expect(record.kept.id, 'a');
    expect(record.kept.name, '家');
    expect(record.removed.map((p) => p.id), ['b']);
    expect(record.diaryRemap, {'d2': 'b', 'd3': 'b'});
    expect(record.placeOrder, ['a', 'b', 'c']);

    // 地点表：保留方改名，b 消失
    final after = await places.getAllPlaces();
    expect(after.map((p) => p.id), ['a', 'c']);
    expect(after.first.name, '家（合并）');

    // 日记表：d2/d3（含回收站）重指到 a，且 last_modified 被推进
    final moved = await diaries.getDiariesByIds(['d2', 'd3']);
    for (final d in moved) {
      expect(d.placeId, 'a');
      expect(d.lastModified.millisecondsSinceEpoch, greaterThan(100));
    }
    // 原本就指向 a 的日记不受影响
    final d1 = (await diaries.getDiariesByIds(['d1'])).single;
    expect(d1.placeId, 'a');
    expect(d1.lastModified.millisecondsSinceEpoch, 0);

    // 墓碑：被合并方有 place 墓碑
    final tombstones = await TombstoneRepository(db).getAll();
    expect(tombstones.map((t) => t.key), contains(SyncTombstone.placeKey('b')));
  });

  test('撤销：还原保留方原名、原 id 插回被合并方、日记指回、墓碑清除', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));
    await insertDiary('d2', 'b');

    final record = await places.mergePlaces(
      kept: make('a', '家'),
      finalName: '家（合并）',
      removed: [make('b', '家门口', lat: 30.2842)],
      placeOrder: const ['a', 'b'],
      diaries: diaries,
    );
    await places.undoMerge(record, diaries: diaries);

    final restored = await places.getAllPlaces();
    expect(restored.map((p) => p.id), ['a', 'b']);
    expect(restored.firstWhere((p) => p.id == 'a').name, '家');
    final b = restored.firstWhere((p) => p.id == 'b');
    expect(b.name, '家门口');
    // 按撤销时间重新盖章：原样的 lastModified 比合并时写下的墓碑还旧，
    // 同步会跳过这一行，甚至在下一次拉取时把它再删掉。
    expect(b.lastModified.isAfter(DateTime.utc(2026, 9, 5)), isTrue);

    final d2 = (await diaries.getDiariesByIds(['d2'])).single;
    expect(d2.placeId, 'b');
    // 撤销同样推进 last_modified，保证回滚也能同步出去
    expect(d2.lastModified.millisecondsSinceEpoch, greaterThan(0));

    final tombstones = await TombstoneRepository(db).getAll();
    expect(
      tombstones.where((t) => t.key == SyncTombstone.placeKey('b')),
      isEmpty,
    );
  });

  test('事件流：合并发 PlaceUpserted + PlaceDeleted，撤销发 PlaceUpserted', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));

    final placeEvents = <PlaceEvent>[];
    final placeSub = places.placeEvents.listen(placeEvents.add);
    addTearDown(placeSub.cancel);
    final diaryEvents = <DiaryEvent>[];
    final diarySub = diaries.diaryEvents.listen(diaryEvents.add);
    addTearDown(diarySub.cancel);

    await insertDiary('d2', 'b');

    final record = await places.mergePlaces(
      kept: make('a', '家'),
      finalName: '家',
      removed: [make('b', '家门口', lat: 30.2842)],
      placeOrder: const [],
      diaries: diaries,
    );
    await flushEvents();

    expect(placeEvents.map((e) => e.runtimeType), [
      PlaceUpserted,
      PlaceDeleted,
    ]);
    expect((placeEvents[0] as PlaceUpserted).place.id, 'a');
    expect((placeEvents[1] as PlaceDeleted).id, 'b');
    expect(diaryEvents, hasLength(1));
    expect((diaryEvents.single as DiaryUpdated).diary.id, 'd2');
    expect((diaryEvents.single as DiaryUpdated).diary.placeId, 'a');

    placeEvents.clear();
    await places.undoMerge(record, diaries: diaries);
    await flushEvents();

    expect(placeEvents.map((e) => e.runtimeType), [
      PlaceUpserted,
      PlaceUpserted,
    ]);
    expect(placeEvents.map((e) => (e as PlaceUpserted).place.id), ['a', 'b']);
    // 事件带的就是落库的那份快照（被还原的地点已按撤销时间盖章）
    final reopened = (await places.getAllPlaces()).firstWhere(
      (p) => p.id == 'b',
    );
    expect(
      (placeEvents.last as PlaceUpserted).place.lastModified,
      reopened.lastModified,
    );
  });

  test('合并：部分被合并方已不存在时，仅用存在的行继续', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));
    await insertDiary('d2', 'b');

    final record = await places.mergePlaces(
      kept: make('a', '家'),
      finalName: '家',
      removed: [make('b', '家门口', lat: 30.2842), make('ghost', '幽灵')],
      placeOrder: const [],
      diaries: diaries,
    );
    expect(record.removed.map((p) => p.id), ['b']);

    final d2 = (await diaries.getDiariesByIds(['d2'])).single;
    expect(d2.placeId, 'a');
  });

  test('合并：removed 为空或保留方不存在时抛错，且不留半提交状态', () async {
    await places.insertAPlace(make('a', '家'));

    expect(
      () => places.mergePlaces(
        kept: make('a', '家'),
        finalName: '家',
        removed: const [],
        placeOrder: const [],
        diaries: diaries,
      ),
      throwsArgumentError,
    );
    expect(
      () => places.mergePlaces(
        kept: make('ghost', '幽灵'),
        finalName: '幽灵',
        removed: [make('a', '家')],
        placeOrder: const [],
        diaries: diaries,
      ),
      throwsStateError,
    );

    // 事务回滚：a 还在，没有墓碑
    expect(await places.getPlaceById('a'), isNotNull);
    final tombstones = await TombstoneRepository(db).getAll();
    expect(tombstones, isEmpty);
  });

  test('repointDiaries：空列表直接返回；只写库不发事件；查询方法含回收站', () async {
    await places.insertAPlace(make('a', '家'));
    await insertDiary('d1', 'a');
    await insertDiary('d2', 'a', show: false);

    final diaryEvents = <DiaryEvent>[];
    final sub = diaries.diaryEvents.listen(diaryEvents.add);
    addTearDown(sub.cancel);

    // 空列表：不做事
    expect(
      await diaries.repointDiaries(const [], 'a', at: DateTime.timestamp()),
      isEmpty,
    );

    // 事务里的写不发事件：提交后由调用方 publishDiaryUpdates 补发
    final updated = await diaries.repointDiaries(
      await diaries.getDiariesWithPlaceIds(['a']),
      'a',
      at: DateTime.timestamp(),
    );
    await flushEvents();
    expect(updated, hasLength(2));
    expect(diaryEvents, isEmpty);

    diaries.publishDiaryUpdates(updated);
    await flushEvents();
    expect(diaryEvents, hasLength(2));

    final all = await diaries.getDiariesWithPlaceIds(['a']);
    expect(all.map((d) => d.id), unorderedEquals(['d1', 'd2']));
    final byIds = await diaries.getDiariesByIds(['d2']);
    expect(byIds.single.id, 'd2');
    expect(await diaries.getDiariesWithPlaceIds(const []), isEmpty);
    expect(await diaries.getDiariesByIds(const []), isEmpty);
  });
}
