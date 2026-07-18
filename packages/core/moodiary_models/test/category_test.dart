import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('Category holds an optional color', () {
    final c = Category.create(categoryName: 'work', color: 0xFF42A5F5);
    expect(c.color, 0xFF42A5F5);
  });

  test('Category color defaults to null when unset', () {
    final c = Category.create(categoryName: 'life');
    expect(c.color, isNull);
  });
}
