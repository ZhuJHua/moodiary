import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('Diary.empty defaults mood to neutral 0.5', () {
    final d = Diary.empty(type: .tiptap);
    expect(d.mood, 0.5);
  });
}
