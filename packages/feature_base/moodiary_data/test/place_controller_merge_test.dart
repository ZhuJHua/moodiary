import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

import 'support/place_fixtures.dart';

void main() {
  late MoodiaryDatabase db;
  late PlaceRepository placeRepo;
  late DiaryRepository diaryRepo;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    diaryRepo = DiaryRepository(db);
    placeRepo = PlaceRepository(db, diaryRepo);
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        moodiaryDatabaseProvider.overrideWithValue(db),
        placeRepositoryProvider.overrideWithValue(placeRepo),
        diaryRepositoryProvider.overrideWithValue(diaryRepo),
      ],
    );
    final keepAlive = container.listen(placeControllerProvider, (_, _) {});
    addTearDown(() {
      keepAlive.close();
    });
    return container;
  }

  Future<(ProviderContainer, PlaceController)> load() async {
    final container = makeContainer();
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);
    return (container, notifier);
  }

  test('合并：刷新状态并返回凭据', () async {
    await placeRepo.insertAPlace(make('a', '家'));
    await placeRepo.insertAPlace(make('b', '家门口'));
    await placeRepo.insertAPlace(make('c', '公司'));

    final (container, notifier) = await load();

    final record = await notifier.mergePlaces(
      keptId: 'a',
      finalName: '家（合并）',
      removedIds: const ['b'],
    );
    await flushEvents();

    expect(record, isNotNull);
    expect(record!.kept.id, 'a');
    expect(record.removed.map((p) => p.id), ['b']);

    final state = container.read(placeControllerProvider).value!;
    expect(state.map((p) => p.id), ['a', 'c']);
    expect(state.firstWhere((p) => p.id == 'a').name, '家（合并）');
  });

  test('affectedDiaryCount：计数包含回收站，只统计候选地点', () async {
    await placeRepo.insertAPlace(make('a', '家'));
    await placeRepo.insertAPlace(make('b', '公司'));
    await insertDiary(db, 'd1', 'a', time: 100);
    await insertDiary(db, 'd2', 'a', time: 300);
    await insertDiary(db, 'd3', 'a', time: 400, show: false);
    await insertDiary(db, 'd4', 'b', time: 500);

    final (_, notifier) = await load();

    expect(await notifier.affectedDiaryCount(const ['a']), 3);
    expect(await notifier.affectedDiaryCount(const ['a', 'b']), 4);
    expect(await notifier.affectedDiaryCount(const ['a', 'a']), 3);
    expect(await notifier.affectedDiaryCount(const ['ghost']), 0);
    expect(await notifier.affectedDiaryCount(const []), 0);
  });

  test('撤销：控制器销毁后仍可还原数据', () async {
    await placeRepo.insertAPlace(make('a', '家'));
    await placeRepo.insertAPlace(make('b', '家门口'));
    await insertDiary(db, 'd1', 'b', time: 100, show: false);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        moodiaryDatabaseProvider.overrideWithValue(db),
        placeRepositoryProvider.overrideWithValue(placeRepo),
        diaryRepositoryProvider.overrideWithValue(diaryRepo),
      ],
    );
    final subscription = container.listen(placeControllerProvider, (_, _) {});
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);
    final record = await notifier.mergePlaces(
      keptId: 'a',
      finalName: '新家',
      removedIds: const ['b'],
    );
    expect(record, isNotNull);
    subscription.close();
    await container.pump();
    expect(container.read(placeControllerProvider.exists), isFalse);
    container.dispose();

    expect(await notifier.undoMerge(record!), isTrue);
    expect((await placeRepo.getAllPlaces()).map((place) => place.name), [
      '家',
      '家门口',
    ]);
    expect((await diaryRepo.getDiariesByIds(['d1'])).single.placeId, 'b');
  });
}
