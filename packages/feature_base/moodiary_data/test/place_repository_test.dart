import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late PlaceRepository repo;

  Place make(
    String id,
    String name, {
    double lat = 30.2841,
    double lon = 120.1552,
    String? icon,
  }) => Place(
    id: id,
    name: name,
    latitude: lat,
    longitude: lon,
    icon: icon,
    lastModified: DateTime.utc(2026, 9, 5),
  );

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = PlaceRepository(db);
  });

  tearDown(() => db.close());

  test('往返：全部字段原样存取，icon 可空', () async {
    await repo.insertAPlace(make('p1', '公司', icon: 'building-2'));
    await repo.insertAPlace(make('p2', '家'));
    final all = await repo.getAllPlaces();
    expect(all, hasLength(2));
    final company = all.firstWhere((p) => p.id == 'p1');
    expect(company.name, '公司');
    expect(company.icon, 'building-2');
    expect(all.firstWhere((p) => p.id == 'p2').icon, isNull);
  });

  test('删除：有日记引用时拦住；无引用则行硬删 + 写墓碑', () async {
    await repo.insertAPlace(make('p1', '公司'));
    await db
        .into(db.diaries)
        .insert(
          DiariesCompanion.insert(
            id: 'd1',
            title: '',
            content: '',
            contentText: '',
            time: 0,
            lastModified: 0,
            show: 1,
            mood: 'neutral',
            type: 'tiptap',
            placeId: const Value('p1'),
          ),
        );
    expect(await repo.deleteAPlace('p1'), isFalse, reason: '仍有日记引用');
    expect(await repo.getPlaceById('p1'), isNotNull);
    await (db.delete(db.diaries)..where((d) => d.id.equals('d1'))).go();
    final ok = await repo.deleteAPlace('p1');
    expect(ok, isTrue);
    expect(await repo.getPlaceById('p1'), isNull);
    final rows = await TombstoneRepository(db).getAll();
    expect(rows.map((t) => t.key), contains(SyncTombstone.placeKey('p1')));
    expect(rows.first.kind, TombstoneKind.place);
  });

  test('删除不存在的地点：返回 false 且不写墓碑', () async {
    expect(await repo.deleteAPlace('ghost'), isFalse);
    final rows = await TombstoneRepository(db).getAll();
    expect(
      rows.where((t) => t.key == SyncTombstone.placeKey('ghost')),
      isEmpty,
    );
  });

  test('按名字找：同名复用，取 id 最小的那个', () async {
    await repo.insertAPlace(make('p2', '杭州市 西湖区'));
    await repo.insertAPlace(make('p1', '杭州市 西湖区'));
    expect((await repo.getPlaceByName('杭州市 西湖区'))?.id, 'p1');
    expect(await repo.getPlaceByName('没有这个'), isNull);
  });

  test('复活闸门：同 id 重新写入会清掉墓碑行', () async {
    await repo.insertAPlace(make('p1', '公司'));
    await repo.deleteAPlace('p1');
    await repo.insertAPlace(make('p1', '公司'));
    final rows = await TombstoneRepository(db).getAll();
    expect(rows.where((t) => t.key == SyncTombstone.placeKey('p1')), isEmpty);
  });

  group('就近匹配', () {
    const lat = 30.2841;
    const lon = 120.1552;

    test('半径内命中，半径外不命中', () {
      final places = [make('p1', '公司')];
      expect(places.matchAt(lat, lon)?.name, '公司');
      expect(places.matchAt(lat + 0.01, lon), isNull);
    });

    test('两个都命中时取最近的那个', () {
      final places = [
        make('far', '园区', lat: lat + 0.0008),
        make('near', '公司', lat: lat + 0.0001),
      ];
      expect(places.matchAt(lat, lon)?.name, '公司');
    });

    test('空列表返回 null', () {
      expect(<Place>[].matchAt(lat, lon), isNull);
    });
  });

  test('Haversine 距离与已知值一致（±1%）', () {
    final d = distanceMeters(30.0, 120.0, 30.01, 120.0);
    expect(d, closeTo(1111, 11));
    expect(distanceMeters(30.0, 120.0, 30.0, 120.0), 0);
  });

  test('applyPlaceOrder：清单排在前，其余按 id 补在后', () {
    final places = [make('a', 'A'), make('b', 'B'), make('c', 'C')];
    expect(applyPlaceOrder(places, ['c', 'a']).map((p) => p.id), [
      'c',
      'a',
      'b',
    ]);
    expect(applyPlaceOrder(places, const []).map((p) => p.id), ['a', 'b', 'c']);
    expect(applyPlaceOrder(places, ['zzz', 'b']).map((p) => p.id), [
      'b',
      'a',
      'c',
    ]);
  });
}
