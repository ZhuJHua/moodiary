import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late MemoryRepository repo;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = MemoryRepository(db);
  });

  tearDown(() => db.close());

  Future<MemoryEntry> save(
    String text, {
    String category = 'preference',
    bool pinned = false,
  }) async {
    final entry = MemoryEntry.create(
      category: category,
      text: text,
    ).copyWith(pinned: pinned);
    await repo.put(entry);
    return entry;
  }

  group('常驻集合只认 pinned', () {
    test('没钉过的 preference 不进常驻——老数据的类别是旧规则下随手打的', () async {
      await save('叫我小竹');
      expect(await repo.profileFacts(), isEmpty);
    });

    test('钉过的才进，跟类别无关', () async {
      await save('每周跑三次', category: 'goal', pinned: true);
      final facts = await repo.profileFacts();
      expect(facts, hasLength(1));
      expect(facts.single.text, '每周跑三次');
    });

    test('按最近更新排序，并受上限约束', () async {
      for (var i = 0; i < 8; i++) {
        await save('偏好 $i', pinned: true);
      }
      expect(await repo.profileFacts(limit: 6), hasLength(6));
    });

    test('pinnedCount 只数钉过的', () async {
      await save('a', pinned: true);
      await save('b');
      await save('c', category: 'goal', pinned: true);
      expect(await repo.pinnedCount(), 2);
    });

    test('取消常驻后立刻退出常驻集合', () async {
      final entry = await save('叫我小竹', pinned: true);
      await repo.setPinned(entry.id, false);
      expect(await repo.profileFacts(), isEmpty);
    });
  });

  group('写入去重', () {
    test('同一句话换标点大小写不会变成第二条', () async {
      await save('I run on Mondays.');
      final dup = await repo.findDuplicate('preference', 'i run on mondays');
      expect(dup, isNotNull);
    });

    test('中文标点同样归一', () async {
      await save('晚上十一点后，不聊沉重的话题。');
      final dup = await repo.findDuplicate(
        'preference',
        '晚上十一点后不聊沉重的话题',
      );
      expect(dup, isNotNull);
    });

    test('类别不同不算重复', () async {
      await save('跑步');
      expect(await repo.findDuplicate('goal', '跑步'), isNull);
    });

    test('touch 只动更新时间', () async {
      final entry = await save('叫我小竹');
      await repo.touch(entry.id);
      final after = await repo.get(entry.id);
      expect(after!.text, entry.text);
      expect(after.updatedAt.isAfter(entry.updatedAt), isTrue);
    });
  });
}
