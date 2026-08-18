import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/presentation/assistant_page.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  // 本地时刻，分桶只认本地日历。
  final now = DateTime(2026, 8, 18, 14, 30);

  ChatSession at(DateTime local) => ChatSession.create(
    providerId: 'p',
    model: 'm',
  ).copyWith(updatedAt: local.toUtc());

  List<SessionHistoryBucket> bucketsOf(List<ChatSession> sessions) =>
      sessionHistoryGroups(sessions, now: now).map((g) => g.bucket).toList();

  test('今天从零点算起，不是「24 小时以内」', () {
    final groups = sessionHistoryGroups([
      at(DateTime(2026, 8, 18, 0, 0)),
      at(DateTime(2026, 8, 17, 23, 59)),
    ], now: now);
    expect(bucketsOf([at(DateTime(2026, 8, 18, 0, 0))]), <SessionHistoryBucket>[
      .today,
    ]);
    expect(groups.map((g) => g.bucket).toList(), <SessionHistoryBucket>[
      .today,
      .last7,
    ]);
  });

  test('近 7 天的边界与日记搜索一致：今天零点往前 7 天', () {
    // 8/11 00:00 正好是边界，算在内；再早一秒落到「更早」。
    expect(bucketsOf([at(DateTime(2026, 8, 11, 0, 0))]), <SessionHistoryBucket>[
      .last7,
    ]);
    expect(
      bucketsOf([at(DateTime(2026, 8, 10, 23, 59, 59))]),
      <SessionHistoryBucket>[.earlier],
    );
  });

  test('空桶不出现，桶序与倒序取出的会话同向', () {
    final groups = sessionHistoryGroups([
      at(DateTime(2026, 8, 18, 9)),
      at(DateTime(2026, 8, 1)),
    ], now: now);
    expect(groups.map((g) => g.bucket).toList(), <SessionHistoryBucket>[
      .today,
      .earlier,
    ]);
  });

  test('桶内顺序原样保留，不重排', () {
    final first = at(DateTime(2026, 8, 18, 14));
    final second = at(DateTime(2026, 8, 18, 9));
    final groups = sessionHistoryGroups([first, second], now: now);
    expect(groups.single.sessions.map((s) => s.id).toList(), [
      first.id,
      second.id,
    ]);
  });

  test('全都落在同一桶时只有一组（标题照画，见 _entries）', () {
    final groups = sessionHistoryGroups([
      at(DateTime(2026, 8, 1)),
      at(DateTime(2026, 7, 3)),
    ], now: now);
    expect(groups.length, 1);
    expect(groups.single.bucket, SessionHistoryBucket.earlier);
  });

  test('空列表不产生任何桶', () {
    expect(sessionHistoryGroups(const [], now: now), isEmpty);
  });

  test('落库的 UTC 时刻按本地日历分桶，不按 UTC 日历', () {
    // 8/18 00:30 本地 = UTC 前一天（在 UTC+n 的机器上）。少一次 toLocal 就会掉到
    // 「近 7 天」。UTC 机器上两者无差别，这条只在有时区偏移时才真正判别。
    final session = at(DateTime(2026, 8, 18, 0, 30));
    expect(session.updatedAt.isUtc, isTrue);
    expect(bucketsOf([session]), <SessionHistoryBucket>[.today]);
  });
}
