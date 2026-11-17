import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

void main() {
  final now = DateTime(2026, 11, 17, 14, 5, 37, 123);
  final original = DateTime(2026, 10, 21, 23, 45, 15, 456);
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> call(
    ToolSurface surface,
    String name,
    Map<String, Object?> args,
  ) async {
    final definition = moodiaryTools.firstWhere((tool) => tool.name == name);
    final result = await definition.call(
      args,
      ToolContext(
        diaries: diaries,
        categories: categories,
        insights: MoodInsightsRepository(db),
        surface: surface,
        now: () => now,
      ),
    );
    expect(await definition.output.validate(result.data), isEmpty);
    return result.data;
  }

  Future<Map> write(String name, Map<String, Object?> item) async =>
      ((await call(ToolSurface.assistant, name, {
                    'items': [item],
                  }))['results']
                  as List)
              .single
          as Map;

  final cases = <(String, Object?, DateTime, DateTime)>[
    (
      'bare date',
      '2026-11-10',
      DateTime(2026, 11, 10, 14, 5, 37, 123),
      DateTime(2026, 11, 10, 23, 45, 15, 456),
    ),
    (
      'local datetime to the minute',
      '2026-11-10T21:30',
      DateTime(2026, 11, 10, 21, 30),
      DateTime(2026, 11, 10, 21, 30),
    ),
    (
      'local datetime with seconds',
      '2026-11-10T21:30:15',
      DateTime(2026, 11, 10, 21, 30, 15),
      DateTime(2026, 11, 10, 21, 30, 15),
    ),
    (
      'offset datetime crossing a day boundary',
      '2026-11-10T00:30:15+09:00',
      DateTime.utc(2026, 11, 9, 15, 30, 15),
      DateTime.utc(2026, 11, 9, 15, 30, 15),
    ),
    (
      'UTC datetime',
      '2026-11-10T21:30:15Z',
      DateTime.utc(2026, 11, 10, 21, 30, 15),
      DateTime.utc(2026, 11, 10, 21, 30, 15),
    ),
    (
      'future date',
      '2030-01-01',
      DateTime(2030, 1, 1, 14, 5, 37, 123),
      DateTime(2030, 1, 1, 23, 45, 15, 456),
    ),
    ('absent time', null, now, original),
  ];

  for (final (label, input, createdTime, updatedTime) in cases) {
    test('$label on create and update', () async {
      final created = await write('create_diary', {
        'content': 'Back-filled diary',
        'time': ?input,
        'tags': ['travel'],
      });
      expect(created['ok'], true);
      final summary = created['diary'] as Map;
      final id = summary['id'] as String;
      expect(DateTime.parse(summary['time'] as String), createdTime.toUtc());
      expect(summary['timeLocal'], isoLocal(createdTime));
      expect(summary['tags'], ['travel']);
      expect(
        (await diaries.getDiaryByBusinessId(id))!.time,
        createdTime.toUtc(),
      );

      await diaries.insertADiary(
        makeDiary('existing', 'Original', time: original),
      );
      final updated = await write('update_diary', {
        'id': 'existing',
        'time': ?input,
        'tags': ['travel', 'family'],
      });
      expect(updated['ok'], true);
      final changed = updated['diary'] as Map;
      expect(DateTime.parse(changed['time'] as String), updatedTime.toUtc());
      expect(changed['timeLocal'], isoLocal(updatedTime));
      expect(changed['tags'], ['travel', 'family']);
      expect(
        (await diaries.getDiaryByBusinessId('existing'))!.time,
        updatedTime.toUtc(),
      );
    });
  }

  for (final input in [
    '',
    'yesterday',
    '2026-02-30',
    '2026-11-10T25:30',
    '2026-11-10T21:99',
    '2026-11-10T21:30+25:00',
  ]) {
    test('rejects invalid time "$input" without writing', () async {
      await diaries.insertADiary(
        makeDiary('existing', 'Original', time: original),
      );
      for (final name in ['create_diary', 'update_diary']) {
        final result = await write(name, {
          if (name == 'update_diary') 'id': 'existing',
          'content': 'Changed',
          'time': input,
        });
        expect(result['ok'], false);
        expect(result['error'], contains('$name: time'));
      }
      final stored = (await diaries.getAllDiaries()).single;
      expect(stored.time, original.toUtc());
      expect(stored.contentText, 'Original');
    });
  }

  test('null time uses now on create and keeps time on update', () async {
    final created = await write('create_diary', {
      'content': 'Body',
      'time': null,
    });
    expect(created['ok'], true);
    final id = (created['diary'] as Map)['id'] as String;
    final updated = await write('update_diary', {
      'id': id,
      'time': null,
      'title': 'New',
    });
    expect(updated['ok'], true);
    expect((await diaries.getDiaryByBusinessId(id))!.time, now.toUtc());
  });

  test('get and search expose local minutes and existing tags', () async {
    await diaries.insertADiary(
      makeDiary('existing', 'Original', time: original, tags: ['travel']),
    );
    for (final name in ['get_diary', 'search_diaries']) {
      final result = await call(ToolSurface.assistant, name, {
        if (name == 'get_diary') 'ids': ['existing'],
      });
      final rows = result[name == 'get_diary' ? 'diaries' : 'hits'] as List;
      final row = rows.single as Map;
      expect(row['timeLocal'], isoLocal(original));
      expect(row['timeLocal'], contains('T23:45'));
      expect(row['tags'], ['travel']);
    }
    final tags = await call(ToolSurface.assistant, 'list_tags', {});
    expect((tags['tags'] as List).single['tag'], 'travel');
  });

  test('invalid time is an argument error naming the field', () {
    expect(
      () =>
          resolveDiaryTime('invalid', reference: now, subject: 'create_diary'),
      throwsA(
        isA<ToolArgumentException>().having(
          (error) => error.message,
          'message',
          contains('time'),
        ),
      ),
    );
  });
}
