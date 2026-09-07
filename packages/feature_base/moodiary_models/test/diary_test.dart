import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('Diary.empty defaults mood to neutral', () {
    final d = Diary.empty(type: .tiptap);
    expect(d.mood, DiaryMood.neutral);
  });

  test('DiaryMood JSON round-trips by name and falls back to neutral', () {
    final d = Diary.empty(type: .tiptap).copyWith(mood: .positive);
    final json = d.toJson();
    expect(json['mood'], 'positive');
    expect(Diary.fromJson(json).mood, DiaryMood.positive);
    expect(DiaryMood.fromName('nope'), DiaryMood.neutral);
  });
}
