import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/moodiary_diary.dart';

void main() {
  test('filter and selection survive a gap between listeners', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final filter = container.listen(homeDiaryFilterProvider, (_, _) {});
    final selection = container.listen(diarySelectionProvider, (_, _) {});
    container
        .read(homeDiaryFilterProvider.notifier)
        .select(const DiaryFilter.tag('trip'));
    container.read(diarySelectionProvider.notifier).enter('diary');
    filter.close();
    selection.close();
    await container.pump();
    expect(
      container.read(homeDiaryFilterProvider),
      const DiaryFilter.tag('trip'),
    );
    expect(container.read(diarySelectionProvider), {'diary'});
  });

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
