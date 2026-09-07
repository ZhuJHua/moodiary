import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/calendar/calendar_page.dart';

void main() {
  group('monthGeometry', () {
    test('周日打头：1 号是周日时前面不空格', () {
      expect(monthGeometry(DateTime(2026, 2)).leading, 0);
    });

    test('周日打头：1 号是周六时前面空六格', () {
      expect(monthGeometry(DateTime(2026, 8)).leading, 6);
    });

    test('周一被算成 1 格而不是 0 格', () {
      expect(monthGeometry(DateTime(2026, 6)).leading, 1);
    });

    test('天数覆盖 30 / 31 / 平年二月 / 闰年二月', () {
      expect(monthGeometry(DateTime(2026, 4)).days, 30);
      expect(monthGeometry(DateTime(2026, 8)).days, 31);
      expect(monthGeometry(DateTime(2026, 2)).days, 28);
      expect(monthGeometry(DateTime(2028, 2)).days, 29);
    });

    test('12 月不会越界到下一年', () {
      expect(monthGeometry(DateTime(2026, 12)).days, 31);
    });

    test('传进来带时分秒也只看年月', () {
      final noisy = DateTime(2026, 8, 17, 23, 59, 59);
      expect(monthGeometry(noisy), monthGeometry(DateTime(2026, 8)));
    });
  });

  group('页码 ↔ 月份', () {
    final anchor = DateTime(2026, 8);

    test('锚月落在锚页上，来回换算不掉精度', () {
      for (var delta = -400; delta <= 400; delta++) {
        final month = DateTime(anchor.year, anchor.month + delta);
        final page = pageForMonth(anchor, month);
        expect(monthForPage(anchor, page), month, reason: 'delta=$delta');
      }
    });

    test('相邻页正好差一个月，跨年也是', () {
      final page = pageForMonth(anchor, DateTime(2026, 12));
      expect(monthForPage(anchor, page), DateTime(2026, 12));
      expect(monthForPage(anchor, page + 1), DateTime(2027, 1));
      expect(monthForPage(anchor, page - 12), DateTime(2025, 12));
    });

    test('往锚点之前翻不会差一整年', () {
      expect(
        monthForPage(anchor, pageForMonth(anchor, anchor) - 8),
        DateTime(2025, 12),
      );
      expect(
        monthForPage(anchor, pageForMonth(anchor, anchor) - 20),
        DateTime(2024, 12),
      );
    });
  });
}
