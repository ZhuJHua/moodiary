import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('every legacy emotion maps to its new level or unset', () {
    const expected = <String, DiaryMood?>{
      'fulfilled': .great,
      'love': .great,
      'positive': .good,
      'neutral': null,
      'negative': .bad,
      'anxious': .bad,
      'tired': .bad,
      'speechless': .bad,
      'sick': .bad,
      'angry': .awful,
    };
    for (final entry in expected.entries) {
      final result = LegacyMood.fromName(entry.key)!;
      expect(result.mood, entry.value, reason: entry.key);
      expect(result.scene, isNull);
    }
    expect(LegacyMood.fromName('unknown'), isNull);
    expect(LegacyMood.fromName(null), isNull);
  });
  test('all six scenes are returned as data, with no mood', () {
    for (final scene in LegacyMoodScene.values) {
      final result = LegacyMood.fromName(scene.name)!;
      expect(result.mood, isNull);
      expect(result.scene, scene);
    }
  });
}
