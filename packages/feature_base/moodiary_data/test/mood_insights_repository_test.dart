import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late MoodInsightsRepository repository;
  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    repository = MoodInsightsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert(
    String id,
    DateTime time, {
    int? mood,
    bool visible = true,
  }) async {
    await db
        .into(db.diaries)
        .insert(
          DiariesCompanion.insert(
            id: id,
            title: 'Title $id',
            content: '{}',
            contentText: 'x' * 200,
            time: dbTime(time),
            lastModified: dbTime(time),
            show: visible ? 1 : 0,
            moodLevel: Value(mood),
            type: 'text',
          ),
        );
  }

  test('light projection respects visibility, local half-open bounds and preview length', () async {
    final start = DateTime(2026, 10, 1);
    final end = DateTime(2026, 11, 1);
    await insert(
      'before',
      start.subtract(const Duration(microseconds: 1)),
      mood: 1,
    );
    await insert('first', start, mood: 4);
    await insert('hidden', start, mood: 5, visible: false);
    await insert('none', DateTime(2026, 10, 31, 23, 59));
    await insert('end', end, mood: 5);
    final rows = await repository.entries(start, end);
    expect(rows.map((e) => e.id), ['none', 'first']);
    expect(rows.last.time.toLocal(), start);
    expect(rows.last.mood, DiaryMood.good);
    expect(rows.first.mood, isNull);
    expect(rows.last.title, 'Title first');
    expect(rows.last.preview.length, 120);
  });

  test(
    'earliest diary includes null moods but excludes hidden diaries',
    () async {
      expect(await repository.earliestEntry(), isNull);
      await insert('hidden-oldest', DateTime(2020), visible: false);
      final first = DateTime(2023, 12, 31, 23, 30);
      await insert('no-mood', first);
      await insert('recorded', DateTime(2026), mood: 5);
      expect((await repository.earliestEntry())?.toLocal(), first);
    },
  );

  test('ever recorded ignores hidden entries and unrecorded moods', () async {
    expect(await repository.hasRecordedMood(), isFalse);
    await insert('hidden', DateTime(2026), mood: 3, visible: false);
    await insert('none', DateTime(2026));
    expect(await repository.hasRecordedMood(), isFalse);
    await insert('recorded', DateTime(2025), mood: 2);
    expect(await repository.hasRecordedMood(), isTrue);
  });
}
