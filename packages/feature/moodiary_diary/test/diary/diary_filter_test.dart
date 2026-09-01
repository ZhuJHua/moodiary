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

    // 关键：「未分类」的 categoryId 也是 null，但它不是「全部」。
    expect(none.categoryId, isNull);
    expect(none.isAll, isFalse);
    expect(none.uncategorized, isTrue);
  });

  test('equality distinguishes all from uncategorized', () {
    expect(const DiaryFilter.all(), const DiaryFilter.all());
    expect(const DiaryFilter.all() == const .uncategorized(), isFalse);
    expect(const DiaryFilter.category('a') == const .category('a'), isTrue);
    expect(const DiaryFilter.category('a') == const .category('b'), isFalse);
    expect(
      const DiaryFilter.all().hashCode ==
          const DiaryFilter.uncategorized().hashCode,
      isFalse,
    );
  });
}
