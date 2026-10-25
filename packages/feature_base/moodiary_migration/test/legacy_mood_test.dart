import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('Isar mood boundaries and exact default', () {
    final expected = <double, DiaryMood?>{
      0: .awful,
      0.1999: .awful,
      0.2: .bad,
      0.3999: .bad,
      0.4: .okay,
      0.4999: .okay,
      0.5: null,
      0.5001: .okay,
      0.5999: .okay,
      0.6: .good,
      0.7999: .good,
      0.8: .great,
      1: .great,
    };
    for (final entry in expected.entries) {
      expect(
        EngineMigrationService.moodFromLegacyDouble(entry.key),
        entry.value,
        reason: '${entry.key}',
      );
    }
  });
}
