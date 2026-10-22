import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late MoodiaryDatabase db;
  late PlaceRepository placeRepo;
  late DiaryRepository diaryRepo;

  Place make(String id, String name) => Place(
    id: id,
    name: name,
    latitude: 30.2841,
    longitude: 120.1552,
    lastModified: DateTime.utc(2026, 9, 5),
  );

  Future<void> insertDiary(
    String id,
    String placeId, {
    required int time,
    bool show = true,
  }) => db
      .into(db.diaries)
      .insert(
        DiariesCompanion.insert(
          id: id,
          title: '',
          content: '',
          contentText: '',
          time: time,
          lastModified: time,
          show: show ? 1 : 0,
          mood: 'neutral',
          type: 'tiptap',
          placeId: Value(placeId),
        ),
      );

  setUp(() {
    getIt.pushNewScope();
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    placeRepo = PlaceRepository(db);
    diaryRepo = DiaryRepository(db);
    getIt
      ..registerSingleton<MoodiaryDatabase>(db)
      ..registerSingleton<PlaceRepository>(placeRepo)
      ..registerSingleton<DiaryRepository>(diaryRepo)
      ..registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  tearDown(() async {
    await getIt.popScope();
    await db.close();
  });

  /// broadcast 事件经微任务异步派发，读取刷新后的 state 前先冲刷。
  Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    // placeControllerProvider 是 autoDispose：挂监听防止读取间隙被销毁重建，
    // 否则 state 回到 AsyncLoading，断言处 .value 为 null。
    final keepAlive = container.listen(placeControllerProvider, (_, _) {});
    addTearDown(() {
      keepAlive.close();
      container.dispose();
    });
    return container;
  }

  test('合并：state 刷新、placeOrder 移除被合并方、返回凭据', () async {
    MoodiaryKVs.placeOrder.set(['a', 'b', 'c']);
    await placeRepo.insertAPlace(make('a', '家'));
    await placeRepo.insertAPlace(make('b', '家门口'));
    await placeRepo.insertAPlace(make('c', '公司'));

    final container = makeContainer();
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);

    final record = await notifier.mergePlaces(
      keptId: 'a',
      finalName: '家（合并）',
      removedIds: const ['b'],
    );
    await flushEvents();

    expect(record, isNotNull);
    expect(record!.kept.id, 'a');
    expect(record.removed.map((p) => p.id), ['b']);

    // placeOrder 维护：b 被移除，其余保持
    expect(MoodiaryKVs.placeOrder.get(), ['a', 'c']);

    // state 经事件流刷新：b 消失、a 改名
    final state = container.read(placeControllerProvider).value!;
    expect(state.map((p) => p.id), ['a', 'c']);
    expect(state.firstWhere((p) => p.id == 'a').name, '家（合并）');
  });

  test('合并：keptId 不存在或 removedIds 无效时返回 null，不动数据', () async {
    await placeRepo.insertAPlace(make('a', '家'));
    MoodiaryKVs.placeOrder.set(['a']);

    final container = makeContainer();
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);

    expect(
      await notifier.mergePlaces(
        keptId: 'ghost',
        finalName: 'x',
        removedIds: const ['a'],
      ),
      isNull,
    );
    expect(
      await notifier.mergePlaces(
        keptId: 'a',
        finalName: 'x',
        removedIds: const ['ghost'],
      ),
      isNull,
    );

    expect((await placeRepo.getAllPlaces()).map((p) => p.id), ['a']);
    expect(MoodiaryKVs.placeOrder.get(), ['a']);
  });

  test('撤销：数据与 placeOrder 一并还原', () async {
    MoodiaryKVs.placeOrder.set(['a', 'b', 'c']);
    await placeRepo.insertAPlace(make('a', '家'));
    await placeRepo.insertAPlace(make('b', '家门口'));
    await placeRepo.insertAPlace(make('c', '公司'));

    final container = makeContainer();
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);

    final record = await notifier.mergePlaces(
      keptId: 'a',
      finalName: '家（合并）',
      removedIds: const ['b'],
    );
    expect(record, isNotNull);

    final ok = await notifier.undoMerge(record!);
    expect(ok, isTrue);
    await flushEvents();

    expect(MoodiaryKVs.placeOrder.get(), ['a', 'b', 'c']);
    final state = container.read(placeControllerProvider).value!;
    expect(state.map((p) => p.id), ['a', 'b', 'c']);
    expect(state.firstWhere((p) => p.id == 'a').name, '家');
  });

  test('affectedDiaries：会被改写的日记按时间倒序，回收站也算', () async {
    await placeRepo.insertAPlace(make('a', '家'));
    await insertDiary('d1', 'a', time: 100);
    await insertDiary('d2', 'a', time: 300);
    await insertDiary('d3', 'a', time: 400, show: false);

    final container = makeContainer();
    final notifier = container.read(placeControllerProvider.notifier);
    await container.read(placeControllerProvider.future);

    final affected = await notifier.affectedDiaries(const ['a']);
    expect(affected.map((d) => d.id), ['d3', 'd2', 'd1']);
  });
}
