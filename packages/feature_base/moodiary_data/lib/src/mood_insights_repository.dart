import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'mood_insights.dart';

@lazySingleton
class MoodInsightsRepository {
  MoodInsightsRepository(this._db);
  final MoodiaryDatabase _db;

  /// [start, end) in local calendar time, stored as UTC microseconds.
  Future<List<MoodInsightEntry>> entries(DateTime start, DateTime end) =>
      _db.transaction(() async {
        final variables = [Variable(dbTime(start)), Variable(dbTime(end))];
        final rows = await _db
            .customSelect(
              'SELECT id, time, mood_level, title, substr(content_text, 1, 120) AS preview '
              'FROM diaries WHERE show = 1 AND time >= ? AND time < ? '
              'ORDER BY time DESC, id DESC',
              variables: variables,
              readsFrom: {_db.diaries},
            )
            .get();
        final tagRows = await _db
            .customSelect(
              'SELECT t.diary_id, t.tag FROM diary_tags t '
              'JOIN diaries d ON d.id = t.diary_id '
              'WHERE d.show = 1 AND d.time >= ? AND d.time < ? ORDER BY t.seq',
              variables: variables,
              readsFrom: {_db.diaries, _db.diaryTags},
            )
            .get();
        final tags = <String, List<String>>{};
        for (final row in tagRows) {
          (tags[row.read<String>('diary_id')] ??= []).add(
            row.read<String>('tag'),
          );
        }
        return [
          for (final row in rows)
            MoodInsightEntry(
              id: row.read<String>('id'),
              time: dbToTime(row.read<int>('time')),
              mood: DiaryMood.fromScore(row.readNullable<int>('mood_level')),
              title: row.read<String>('title'),
              preview: row.read<String>('preview'),
              tags: tags[row.read<String>('id')] ?? const [],
            ),
        ];
      });

  /// Includes visible diaries without a mood so picker history matches the diary.
  Future<DateTime?> earliestEntry() async {
    final row = await _db
        .customSelect(
          'SELECT MIN(time) AS first_time FROM diaries WHERE show = 1',
          readsFrom: {_db.diaries},
        )
        .getSingle();
    final time = row.readNullable<int>('first_time');
    return time == null ? null : dbToTime(time);
  }

  Future<bool> hasRecordedMood() async =>
      (await _db
              .customSelect(
                'SELECT 1 FROM diaries WHERE show = 1 AND mood_level IS NOT NULL LIMIT 1',
                readsFrom: {_db.diaries},
              )
              .get())
          .isNotEmpty;
}
