import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/calendar/calendar_page.dart';

void main() {
  group('monthGeometry', () {
    test('周日打头：1 号是周日时前面不空格', () {
      // 2026-02-01 是周日。
      expect(monthGeometry(DateTime(2026, 2)).leading, 0);
    });

    test('周日打头：1 号是周六时前面空六格', () {
      // 2026-08-01 是周六 —— weekday 是 6，% 7 仍是 6。
      expect(monthGeometry(DateTime(2026, 8)).leading, 6);
    });

    test('周一被算成 1 格而不是 0 格', () {
      // 2026-06-01 是周一。weekday == 1，别写成 `weekday - 1`… 也别写成 `% 7 - 1`。
      expect(monthGeometry(DateTime(2026, 6)).leading, 1);
    });

    test('天数覆盖 30 / 31 / 平年二月 / 闰年二月', () {
      expect(monthGeometry(DateTime(2026, 4)).days, 30);
      expect(monthGeometry(DateTime(2026, 8)).days, 31);
      expect(monthGeometry(DateTime(2026, 2)).days, 28);
      expect(monthGeometry(DateTime(2028, 2)).days, 29);
    });

    test('12 月不会越界到下一年', () {
      // DateTime(2026, 13, 0) 会自己归一成 2026-12-31，不需要分支。
      expect(monthGeometry(DateTime(2026, 12)).days, 31);
    });

    test('传进来带时分秒也只看年月', () {
      final noisy = DateTime(2026, 8, 17, 23, 59, 59);
      expect(monthGeometry(noisy), monthGeometry(DateTime(2026, 8)));
    });
  });
}
