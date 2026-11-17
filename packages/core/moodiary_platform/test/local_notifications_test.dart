import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

void main() {
  test('fixed-offset time zone ids preserve their name and wall time', () {
    for (final (id, minutes) in [
      ('GMT+08:00', 480),
      ('GMT-5', -300),
      ('UTC+0530', 330),
      ('UTC-03:30', -210),
      ('GMT+0', 0),
    ]) {
      final location = parseFixedOffsetTimeZone(id);
      expect(location.name, id);
      expect(location.transitionAt, isEmpty);
      expect(location.transitionZone, isEmpty);
      expect(location.zones, hasLength(1));
      expect(location.zones.single.isDst, isFalse);
      final at = TZDateTime(location, 2026, 11, 17, 12);
      expect(at.timeZoneOffset, Duration(minutes: minutes));
      expect(
        at.toUtc(),
        DateTime.utc(2026, 11, 17, 12).subtract(Duration(minutes: minutes)),
      );
    }
  });

  test('unsupported or invalid fixed-offset ids fall back to UTC', () {
    for (final id in [
      '',
      'unknown',
      'GMT',
      'UTC',
      'GMT+24:00',
      'UTC+1260',
      'GMT+8:7',
      'GMT+08:00extra',
      'UTC+99999999999999999999',
    ]) {
      expect(parseFixedOffsetTimeZone(id), same(UTC));
    }
  });
}
