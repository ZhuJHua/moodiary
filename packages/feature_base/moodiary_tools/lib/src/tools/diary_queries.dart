import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_payloads.dart';

class DiaryToolQueries {
  DiaryToolQueries({required this.diaries, required this._tags});

  final DiaryRepository diaries;
  final TagRepository _tags;

  /// Tag usage over visible diaries, most used first.
  Future<
    ({
      List<({String tag, int diaries})> tags,
      int totalDistinct,
      int scannedDiaries,
    })
  >
  tags({required int limit}) async {
    final usage = await _tags.getTagUsage();
    final sorted = usage.where((entry) => entry.count > 0).toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return (
      tags: [
        for (final entry in sorted.take(limit))
          (tag: entry.name, diaries: entry.count),
      ],
      totalDistinct: sorted.length,
      scannedDiaries: (await diaries.diaryCountByCategory()).total,
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
