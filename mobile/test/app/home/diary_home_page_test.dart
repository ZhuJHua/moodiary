import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/home/diary_home_page.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  test('selected tag follows surviving ids and prefers its current name', () {
    final first = Tag.create('Trip');
    final second = Tag.create('Trip');
    final previous = {first.id: first, second.id: second};
    final renamed = second.copyWith(name: 'Travel');
    final deleted = first.copyWith(deleted: true);
    final unrelated = Tag.create('Other');
    String? resolve(List<Tag> current) => resolveSelectedTagName(
      'Trip',
      previous,
      {for (final tag in current) tag.id: tag},
    );

    expect(resolve([first, renamed]), 'Trip');
    expect(resolve([deleted, renamed]), 'Travel');
    expect(resolve([deleted, unrelated]), isNull);
  });
}
