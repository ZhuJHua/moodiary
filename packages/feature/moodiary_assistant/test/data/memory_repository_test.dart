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
    test('没钉过的 preference 不进常驻', () async {
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

  });

  group('recallMemory 的排序', () {
    test('词元重叠多的排前面', () async {
      await save('我在准备十月的半马', category: 'goal');
      await save('我养了一只叫豆豆的猫', category: 'fact');
      final hits = await repo.search('半马');
      expect(hits, isNotEmpty);
      expect(hits.first.text, contains('半马'));
    });

    test('一个都不沾返回空', () async {
      await save('我养了一只猫', category: 'fact');
      expect(await repo.search('quantum'), isEmpty);
    });

    test('空 query 退回最近若干条', () async {
      await save('甲');
      await save('乙');
      final hits = await repo.search('');
      expect(hits, hasLength(2));
    });

    test('中文按字命中', () async {
      await save('晚上十一点后不聊沉重话题');
      final hits = await repo.search('沉重');
      expect(hits, hasLength(1));
    });

  });

  group('写入去重', () {
    test('换标点或大小写不算新的一条', () async {
      await save('I run on Mondays.');
      await save('晚上十一点后，不聊沉重的话题。', category: 'theme');
      expect(await repo.findDuplicate('preference', 'i run on mondays'), isNotNull);
      expect(
        await repo.findDuplicate('theme', '晚上十一点后不聊沉重的话题'),
        isNotNull,
      );
    });

    test('类别不同不算重复', () async {
      await save('跑步');
      expect(await repo.findDuplicate('goal', '跑步'), isNull);
    });

  });
}
