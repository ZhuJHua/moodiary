import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/application/timeline_group.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// [time] / [modified] 按**本地时区**给，分组也按本地日历切——UTC 存储、本地分桶。
Diary diary(DateTime time, {DateTime? modified, String id = 'x'}) => Diary(
  id: id,
  title: '',
  content: '',
  contentText: '',
  time: time,
  lastModified: modified ?? time,
  show: true,
  mood: 0.5,
  imageName: const [],
  audioName: const [],
  videoName: const [],
  tags: const [],
  type: DiaryType.tiptap.value,
);

void main() {
  test('empty input yields no months', () {
    expect(buildTimeline(const [], .timeDesc), isEmpty);
  });

  test('splits by month and keeps input order', () {
    final months = buildTimeline([
      diary(DateTime(2026, 7, 20, 9), id: 'a'),
      diary(DateTime(2026, 7, 2, 9), id: 'b'),
      diary(DateTime(2026, 6, 30, 9), id: 'c'),
    ], .timeDesc);

    expect(months.length, 2);
    expect(months[0].month, DateTime(2026, 7));
    expect(months[0].entries.map((e) => e.diary.id), ['a', 'b']);
    expect(months[1].month, DateTime(2026, 6));
    expect(months[1].entries.map((e) => e.diary.id), ['c']);
  });

  test('dayStart marks only the first entry of each day', () {
    final months = buildTimeline([
      diary(DateTime(2026, 7, 20, 21), id: 'a'),
      diary(DateTime(2026, 7, 20, 9), id: 'b'),
      diary(DateTime(2026, 7, 19, 9), id: 'c'),
    ], .timeDesc);

    final entries = months.single.entries;
    expect(entries.map((e) => e.dayStart), [true, false, true]);
  });

  test('breakBefore only when a whole day is skipped', () {
    final months = buildTimeline([
      diary(DateTime(2026, 7, 20, 9), id: 'a'),
      diary(DateTime(2026, 7, 19, 9), id: 'b'), // 相邻日：不算断档
      diary(DateTime(2026, 7, 16, 9), id: 'c'), // 隔了两天：断档
      diary(DateTime(2026, 7, 16, 8), id: 'd'), // 同日：不算
    ], .timeDesc);

    final entries = months.single.entries;
    expect(entries.map((e) => e.breakBefore), [false, false, true, false]);
  });

  test('breakBefore works the same when sorted ascending', () {
    final months = buildTimeline([
      diary(DateTime(2026, 7, 16, 9), id: 'a'),
      diary(DateTime(2026, 7, 17, 9), id: 'b'),
      diary(DateTime(2026, 7, 20, 9), id: 'c'),
    ], .timeAsc);

    expect(months.single.entries.map((e) => e.breakBefore), [
      false,
      false,
      true,
    ]);
  });

  test('groups by lastModified when sorting by lastModified', () {
    final list = [
      diary(DateTime(2026, 7, 1, 9), modified: DateTime(2026, 8, 20, 9)),
    ];

    expect(buildTimeline(list, .timeDesc).single.month, DateTime(2026, 7));
    expect(
      buildTimeline(list, .lastModifiedDesc).single.month,
      DateTime(2026, 8),
    );
  });

  test('month boundary does not reset day-gap detection', () {
    // 7/1 与 6/29 隔了一天以上，即使跨月也要判成断档。
    final months = buildTimeline([
      diary(DateTime(2026, 7, 1, 9), id: 'a'),
      diary(DateTime(2026, 6, 29, 9), id: 'b'),
    ], .timeDesc);

    expect(months[1].entries.single.breakBefore, isTrue);
  });

  test('a two-day gap across a DST spring-forward still counts as a break', () {
    // 纽约 2026/3/8、柏林 2026/3/29 前拨一小时：相隔两天的两个「本地零点」只差 47h，
    // Duration.inDays 会截断成 1。日键必须按日历天算，不能按本地时刻差算。
    for (final (a, b) in [
      (DateTime(2026, 3, 7, 9), DateTime(2026, 3, 9, 9)),
      (DateTime(2026, 3, 28, 9), DateTime(2026, 3, 30, 9)),
    ]) {
      final months = buildTimeline([
        diary(b, id: 'later'),
        diary(a, id: 'earlier'),
      ], .timeDesc);
      final entries = [for (final m in months) ...m.entries];
      expect(
        entries.last.breakBefore,
        isTrue,
        reason: '${a.month}/${a.day} → ${b.month}/${b.day} 中间空了一整天',
      );
    }
  });

  test('adjacent days across a DST spring-forward are not a break', () {
    final months = buildTimeline([
      diary(DateTime(2026, 3, 9, 9), id: 'later'),
      diary(DateTime(2026, 3, 8, 9), id: 'earlier'),
    ], .timeDesc);
    final entries = [for (final m in months) ...m.entries];
    expect(entries.last.breakBefore, isFalse);
  });

  test('stamp is local time', () {
    final utc = DateTime.utc(2026, 7, 20, 3);
    final entry = buildTimeline([diary(utc)], .timeDesc).single.entries.single;
    expect(entry.stamp, utc.toLocal());
    expect(entry.stamp.isUtc, isFalse);
  });
}
