import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('LunarCalendar.fromSolar', () {
    test('换算基准：1900-01-31 是正月初一', () {
      final l = LunarCalendar.fromSolar(DateTime(1900, 1, 31))!;
      expect((l.year, l.month, l.day, l.isLeapMonth), (1900, 1, 1, false));
    });

    test('2000-01-01 是 1999 年冬月廿五', () {
      final l = LunarCalendar.fromSolar(DateTime(2000, 1, 1))!;
      expect((l.year, l.month, l.day), (1999, 11, 25));
    });

    test('春节锚点', () {
      final cases = [
        (DateTime(2023, 1, 22), 2023, 1, 1),
        (DateTime(2024, 2, 10), 2024, 1, 1),
        (DateTime(2025, 1, 29), 2025, 1, 1),
        (DateTime(2026, 2, 17), 2026, 1, 1),
      ];
      for (final (solar, y, m, d) in cases) {
        final l = LunarCalendar.fromSolar(solar)!;
        expect(
          (l.year, l.month, l.day, l.isLeapMonth),
          (y, m, d, false),
          reason: '$solar',
        );
      }
    });

    test('2026 中秋：2026-09-25 是八月十五', () {
      final l = LunarCalendar.fromSolar(DateTime(2026, 9, 25))!;
      expect((l.year, l.month, l.day), (2026, 8, 15));
    });

    test('闰月：2023-03-22 是闰二月初一', () {
      final l = LunarCalendar.fromSolar(DateTime(2023, 3, 22))!;
      expect((l.year, l.month, l.day, l.isLeapMonth), (2023, 2, 1, true));
    });

    test('闰月：2025-07-25 是闰六月初一', () {
      final l = LunarCalendar.fromSolar(DateTime(2025, 7, 25))!;
      expect((l.year, l.month, l.day, l.isLeapMonth), (2025, 6, 1, true));
    });

    test('范围外返回 null', () {
      expect(LunarCalendar.fromSolar(DateTime(1899, 12, 31)), isNull);
      expect(LunarCalendar.fromSolar(DateTime(2101, 1, 1)), isNull);
    });

    test('忽略时分秒', () {
      final a = LunarCalendar.fromSolar(DateTime(2026, 10, 4, 23, 59, 59))!;
      final b = LunarCalendar.fromSolar(DateTime(2026, 10, 4))!;
      expect((a.year, a.month, a.day), (b.year, b.month, b.day));
    });
  });

  group('LunarCalendar.dayName', () {
    LunarDate d(int day) => LunarDate(year: 2026, month: 8, day: day);

    test('初一返回月份名，闰月加前缀', () {
      expect(LunarCalendar.dayName(d(1)), '八月');
      expect(
        LunarCalendar.dayName(
          const LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true),
        ),
        '闰六月',
      );
      expect(
        LunarCalendar.dayName(const LunarDate(year: 2026, month: 1, day: 1)),
        '正月',
      );
    });

    test('初一到初十用“初”', () {
      expect(LunarCalendar.dayName(d(2)), '初二');
      expect(LunarCalendar.dayName(d(9)), '初九');
      expect(LunarCalendar.dayName(d(10)), '初十');
    });

    test('十一到二十用“十”', () {
      expect(LunarCalendar.dayName(d(11)), '十一');
      expect(LunarCalendar.dayName(d(15)), '十五');
      expect(LunarCalendar.dayName(d(20)), '二十');
    });

    test('廿一到三十', () {
      expect(LunarCalendar.dayName(d(21)), '廿一');
      expect(LunarCalendar.dayName(d(24)), '廿四');
      expect(LunarCalendar.dayName(d(30)), '三十');
    });
  });
}
