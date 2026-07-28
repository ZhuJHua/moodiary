import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('TimeFormat', () {
    test('isoDate 补零且不随语言变化', () {
      expect(TimeFormat.isoDate(DateTime(2026, 7, 4)), '2026-07-04');
      expect(TimeFormat.isoDate(DateTime(2026, 11, 23)), '2026-11-23');
    });

    test('同一时刻的 UTC 与本地入参输出一致', () {
      final utc = DateTime.utc(2026, 7, 4, 12, 30, 15);
      expect(TimeFormat.isoDate(utc), TimeFormat.isoDate(utc.toLocal()));
      expect(TimeFormat.fullDateTime(utc), TimeFormat.fullDateTime(utc.toLocal()));
      expect(TimeFormat.timeHms(utc), TimeFormat.timeHms(utc.toLocal()));
    });

    test('fullDateTime 精确到秒', () {
      final s = TimeFormat.fullDateTime(DateTime(2026, 7, 4, 1, 2, 3));
      expect(s, contains('02:03'));
    });

    test('relative：今天给时分，跨年给年月日', () {
      final today = TimeFormat.relative(DateTime.now());
      expect(RegExp(r'^\d{1,2}:\d{2}$').hasMatch(today), isTrue);
      expect(TimeFormat.relative(DateTime(2000, 5, 5, 10, 30)), contains('2000'));
    });
  });
}
