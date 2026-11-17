import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_payloads.dart';

class DiaryToolQueries {
  DiaryToolQueries({required this.diaries});

  final DiaryRepository diaries;

  /// Tag usage over visible diaries, most used first. The database has no tag
  /// index, so this aggregates over every visible diary.
  Future<
    ({
      List<({String tag, int diaries})> tags,
      int totalDistinct,
      int scannedDiaries,
    })
  >
  tags({required int limit}) async {
    final all = await diaries.getAllDiaries();
    final counts = <String, int>{};
    var visible = 0;
    for (final diary in all) {
      if (!diary.show) continue;
      visible++;
      for (final tag in diary.tags) {
        counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return (
      tags: [
        for (final entry in sorted.take(limit))
          (tag: entry.key, diaries: entry.value),
      ],
      totalDistinct: counts.length,
      scannedDiaries: visible,
    );
  }

  /// Link summaries include sorted `dangling` ids missing from the database.
  /// Self-links appear only in backlinks, matching the repository index.
  Future<Map<String, dynamic>> linkSummary(Diary diary) async {
    final forward = await diaries.getForwardLinks(diary.id);
    final backlinks = await diaries.getBacklinks(diary.id);
    final referenced = DiaryContent.of(diary).links.toList()..sort();
    final existing = {
      for (final linked in await diaries.getDiariesByIds(referenced)) linked.id,
    };
    final dangling = referenced
        .where((id) => !existing.contains(id))
        .take(_danglingLimit)
        .toList();
    return {
      'forward': [for (final linked in forward) linkRow(linked)],
      'backlinks': [for (final linked in backlinks) linkRow(linked)],
      'dangling': dangling,
    };
  }
}

/// Upper bound on `dangling`, so one document cannot flood a result with ids.
const int _danglingLimit = 100;

Map<String, dynamic> linkRow(Diary diary) => {
  'id': diary.id,
  'title': diary.title,
  'time': isoUtc(diary.time),
  'timeLocal': isoLocal(diary.time),
};
