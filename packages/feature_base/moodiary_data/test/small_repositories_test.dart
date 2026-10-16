import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => db.close());

  group('CategoryRepository', () {
    test('增删查 + 墓碑 + 复活闸门', () async {
      final repo = CategoryRepository(db);
      final tombs = TombstoneRepository(db);
      final c = Category.create(categoryName: '生活');
      await repo.insertACategory(c);
      expect((await repo.getAllCategories()).single.categoryName, '生活');
      expect((await repo.getCategoryById(c.id))?.id, c.id);

      expect(await repo.deleteACategory(c.id), isTrue);
      expect(await repo.getAllCategories(), isEmpty);
      expect(await tombs.getByKey(SyncTombstone.categoryKey(c.id)), isNotNull);
      await repo.insertACategory(c);
      expect(await tombs.getByKey(SyncTombstone.categoryKey(c.id)), isNull);
    });

    test('分类下有日记时拒绝删除', () async {
      final repo = CategoryRepository(db);
      final c = Category.create(categoryName: '生活');
      await repo.insertACategory(c);
      await db
          .into(db.diaries)
          .insert(
            DiariesCompanion.insert(
              id: 'd1',
              categoryId: Value(c.id),
              title: '',
              content: '',
              contentText: '',
              time: 0,
              lastModified: 0,
              show: 1,
              mood: 'neutral',
              type: 'tiptap',
            ),
          );
      expect(await repo.deleteACategory(c.id), isFalse);
      expect(await repo.getAllCategories(), hasLength(1));
    });
  });

  group('TombstoneRepository', () {
    test('putAll / deleteByKeys / purgeExpired', () async {
      final repo = TombstoneRepository(db);
      final now = DateTime.utc(2026, 6, 1);
      await repo.putAll([
        SyncTombstone.forDiary(
          'old',
          at: now.subtract(const Duration(days: 91)),
        ),
        SyncTombstone.forDiary('fresh', at: now),
        SyncTombstone(
          key: SyncTombstone.categoryKey('c'),
          timeMs: now.millisecondsSinceEpoch,
          pushedBackends: const ['backend-a'],
        ),
      ]);
      expect(await repo.getAll(), hasLength(3));
      final pushed = (await repo.getByKey(SyncTombstone.categoryKey('c')))!;
      expect(pushed.pushedBackends, ['backend-a']);
      expect(pushed.kind, TombstoneKind.category);
      expect(pushed.entityId, 'c');

      final purged = await repo.purgeExpired(now: now);
      expect(purged, 1);
      expect(await repo.getByKey(SyncTombstone.diaryKey('old')), isNull);

      await repo.deleteByKeys([SyncTombstone.diaryKey('fresh')]);
      expect(await repo.getAll(), hasLength(1));
    });
  });

  group('FontRepository', () {
    test('按 family upsert / 查 / 删，字重轴 JSON 往返', () async {
      final repo = FontRepository(db);
      const font = Font(
        fontFileName: 'LXGW.ttf',
        fontWghtAxisMap: {'wght': 400},
      );
      await repo.insertFont(font);
      final got = (await repo.getFontByFontFamily('LXGW'))!;
      expect(got.fontFileName, 'LXGW.ttf');
      expect(got.fontWghtAxisMap, {'wght': 400});
      expect(got.fontType, '.ttf');

      await repo.deleteFontByFamily('LXGW');
      expect(await repo.getAllFonts(), isEmpty);
    });
  });
}
