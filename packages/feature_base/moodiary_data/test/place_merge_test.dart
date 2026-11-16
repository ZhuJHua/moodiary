import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'support/place_fixtures.dart';

void main() {
  late MoodiaryDatabase db;
  late PlaceRepository places;
  late DiaryRepository diaries;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    diaries = DiaryRepository(db);
    places = PlaceRepository(db, diaries);
  });

  tearDown(() => db.close());

  test('合并：改名保留方、日记（含回收站）重指、被合并方删除并留墓碑', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));
    await places.insertAPlace(make('c', '公司', lat: 30.6));
    await insertDiary(db, 'd1', 'a');
    await insertDiary(db, 'd2', 'b', lastModified: 100);
    await insertDiary(db, 'd3', 'b', show: false);

    final record = await places.mergePlaces(
      keptId: 'a',
      finalName: '家（合并）',
      removedIds: ['b'],
    );

    expect(record.kept.id, 'a');
    expect(record.kept.name, '家');
    expect(record.removed.map((p) => p.id), ['b']);
    expect(record.diaryRemap, {'d2': 'b', 'd3': 'b'});

    final after = await places.getAllPlaces();
    expect(after.map((p) => p.id), ['a', 'c']);
    expect(after.first.name, '家（合并）');

    final moved = await diaries.getDiariesByIds(['d2', 'd3']);
    for (final d in moved) {
      expect(d.placeId, 'a');
      expect(d.lastModified.millisecondsSinceEpoch, greaterThan(100));
    }

    final d1 = (await diaries.getDiariesByIds(['d1'])).single;
    expect(d1.placeId, 'a');
    expect(d1.lastModified.millisecondsSinceEpoch, 0);

    final tombstones = await TombstoneRepository(db).getAll();
    expect(tombstones.map((t) => t.key), contains(SyncTombstone.placeKey('b')));
  });

  test('撤销：还原保留方原名、原 id 插回被合并方、日记指回、墓碑清除', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口', lat: 30.2842));
    await insertDiary(db, 'd2', 'b');

    final record = await places.mergePlaces(
      keptId: 'a',
      finalName: '家（合并）',
      removedIds: ['b'],
    );
    await places.undoMerge(record);

    final restored = await places.getAllPlaces();
    expect(restored.map((p) => p.id), ['a', 'b']);
    expect(restored.firstWhere((p) => p.id == 'a').name, '家');
    final b = restored.firstWhere((p) => p.id == 'b');
    expect(b.name, '家门口');

    expect(b.lastModified.isAfter(DateTime.utc(2026, 9, 5)), isTrue);

    final d2 = (await diaries.getDiariesByIds(['d2'])).single;
    expect(d2.placeId, 'b');

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

    await insertDiary(db, 'd2', 'b');

    final record = await places.mergePlaces(
      keptId: 'a',
      finalName: '家',
      removedIds: ['b'],
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
    await places.undoMerge(record);
    await flushEvents();

    expect(placeEvents.map((e) => e.runtimeType), [
      PlaceUpserted,
      PlaceUpserted,
    ]);
    expect(placeEvents.map((e) => (e as PlaceUpserted).place.id), ['a', 'b']);

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
    await insertDiary(db, 'd2', 'b');

    final record = await places.mergePlaces(
      keptId: 'a',
      finalName: '家',
      removedIds: ['b', 'ghost'],
    );
    expect(record.removed.map((p) => p.id), ['b']);

    final d2 = (await diaries.getDiariesByIds(['d2'])).single;
    expect(d2.placeId, 'a');
  });

  test('合并：保留方不存在时抛错，且不留半提交状态', () async {
    await places.insertAPlace(make('a', '家'));

    expect(
      () => places.mergePlaces(
        keptId: 'ghost',
        finalName: '幽灵',
        removedIds: ['a'],
      ),
      throwsStateError,
    );

    expect(await places.getPlaceById('a'), isNotNull);
    final tombstones = await TombstoneRepository(db).getAll();
    expect(tombstones, isEmpty);
  });

  test('批量重指：跨分块更新元数据，不改写其他日记', () async {
    await places.insertAPlace(make('a', '家'));
    await places.insertAPlace(make('b', '家门口'));
    await db.batch((batch) {
      batch.insertAll(db.diaries, [
        for (var index = 0; index < 5001; index++)
          DiariesCompanion.insert(
            id: 'moved-$index',
            title: '标题-$index',
            content: '',
            contentText: '',
            time: index,
            lastModified: 100,
            show: index.isEven ? 1 : 0,
            type: 'tiptap',
            placeId: const Value('b'),
          ),
      ]);
    });
    await insertDiary(db, 'untouched', 'a', lastModified: 5000);
    final before = await diaries.getDiariesWithPlaceIds(['b']);
    final at = DateTime.utc(2026, 11, 14);

    final updated = await db.transaction(
      () => diaries.repointDiaries(before, 'a', at: at),
    );

    expect(updated, hasLength(5001));
    expect(updated.every((diary) => diary.placeId == 'a'), isTrue);
    expect(updated.every((diary) => diary.lastModified == at), isTrue);
    expect(await diaries.countDiariesWithPlaceIds(['b']), 0);
    expect(await diaries.countDiariesWithPlaceIds(['a']), 5002);
    final boundary = await diaries.getDiariesByIds([
      'moved-4999',
      'moved-5000',
    ]);
    expect(boundary.every((diary) => diary.placeId == 'a'), isTrue);
    expect(boundary.every((diary) => diary.lastModified == at), isTrue);
    expect(
      boundary.map((diary) => diary.title),
      unorderedEquals(['标题-4999', '标题-5000']),
    );
    final untouched = (await diaries.getDiariesByIds(['untouched'])).single;
    expect(untouched.lastModified.microsecondsSinceEpoch, 5000);
  });

  test('重指日记后仅在发布时通知事件', () async {
    await places.insertAPlace(make('a', '家'));
    await insertDiary(db, 'd1', 'a');
    await insertDiary(db, 'd2', 'a', show: false);

    final diaryEvents = <DiaryEvent>[];
    final sub = diaries.diaryEvents.listen(diaryEvents.add);
    addTearDown(sub.cancel);

    final updated = await diaries.repointDiaries(
      await diaries.getDiariesWithPlaceIds(['a']),
      'a',
      at: DateTime.timestamp(),
    );
    await flushEvents();
    expect(diaryEvents, isEmpty);

    diaries.publishDiaryUpdates(updated);
    await flushEvents();
    expect(diaryEvents, hasLength(2));
  });
}
