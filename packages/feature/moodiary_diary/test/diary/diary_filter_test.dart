import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';

void main() {
  test('three states are mutually exclusive', () {
    const all = DiaryFilter.all();
    const cat = DiaryFilter.category('tr');
    const none = DiaryFilter.uncategorized();

    expect(all.isAll, isTrue);
    expect(all.uncategorized, isFalse);
    expect(all.categoryId, isNull);

    expect(cat.isAll, isFalse);
    expect(cat.categoryId, 'tr');

    expect(none.categoryId, isNull);
    expect(none.isAll, isFalse);
    expect(none.uncategorized, isTrue);

    expect(all == none, isFalse);
    expect(cat == const DiaryFilter.category('b'), isFalse);
  });
}
