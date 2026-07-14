import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('TimeUtil', () {
    test('isoDate 补零且不随语言变化', () {
      expect(TimeUtil.isoDate(DateTime(2026, 7, 4)), '2026-07-04');
      expect(TimeUtil.isoDate(DateTime(2026, 11, 23)), '2026-11-23');
    });

    test('同一时刻的 UTC 与本地入参输出一致', () {
      final utc = DateTime.utc(2026, 7, 4, 12, 30, 15);
      expect(TimeUtil.isoDate(utc), TimeUtil.isoDate(utc.toLocal()));
      expect(TimeUtil.fullDateTime(utc), TimeUtil.fullDateTime(utc.toLocal()));
      expect(TimeUtil.timeHms(utc), TimeUtil.timeHms(utc.toLocal()));
    });

    test('fullDateTime 精确到秒', () {
      final s = TimeUtil.fullDateTime(DateTime(2026, 7, 4, 1, 2, 3));
      expect(s, contains('02:03'));
    });

    test('relative：今天给时分，跨年给年月日', () {
      final today = TimeUtil.relative(DateTime.now());
      expect(RegExp(r'^\d{1,2}:\d{2}$').hasMatch(today), isTrue);
      expect(TimeUtil.relative(DateTime(2000, 5, 5, 10, 30)), contains('2000'));
    });
  });
}
