import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/search_controller.dart';
import 'package:moodiary_diary/src/presentation/search/search_page.dart';
import 'package:moodiary_diary/src/presentation/search/search_result_card.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

final _travel = Tag.legacy('Travel');
final _work = Tag.legacy('Work');
final _hit = DiarySearchHit(
  diary: Diary.empty(type: .tiptap).copyWith(tagIds: [_travel.id, _work.id]),
  titleHighlight: 'Diary',
  excerpt: 'Excerpt',
);

class _Search extends DiarySearchController {
  @override
  DiarySearchState build() => const DiarySearchState();

  @override
  Future<void> setTag(String? tagName) async {
    state = DiarySearchState(
      tagName: tagName,
      results: tagName == null ? [] : [_hit],
      totalCount: tagName == null ? 0 : 1,
    );
  }
}

void main() {
  final catalog = tagCatalogProvider.overrideWithValue(
    .data((
      byId: {_travel.id: _travel, _work.id: _work},
      usage: [
        for (final tag in [_travel, _work])
          (name: tag.name, ids: {tag.id}, count: 1, lastUsed: null),
      ],
    )),
  );

  testWidgets('tag chip applies and clears a tag with an empty query', (
    tester,
  ) async {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    addTearDown(getIt.reset);
    MoodiaryKVs.searchIndexBackfilled.set(true);
    await tester.pumpWidget(
      muiTestApp(
        const DiarySearchPage(),
        overrides: [
          catalog,
          orderedCategoriesProvider.overrideWithValue(const .data([])),
          diarySearchControllerProvider.overrideWith(_Search.new),
        ],
      ),
    );
    await tester.tap(find.text('全部标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MChip, 'Travel'));
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    expect(find.byType(SearchResultCard), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('#Travel')).style!.backgroundColor,
      isNotNull,
    );
    expect(
      tester.widget<Text>(find.text('#Work')).style!.backgroundColor,
      isNull,
    );

    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MChip, '全部标签'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history')), findsOneWidget);
  });

  testWidgets('card highlights a case-insensitive tag substring', (
    tester,
  ) async {
    await tester.pumpWidget(
      muiTestApp(
        SearchResultCard(hit: _hit, query: '  OR  '),
        overrides: [catalog],
      ),
    );
    expect(
      tester.widget<Text>(find.text('#Work')).style!.backgroundColor,
      isNotNull,
    );
    expect(
      tester.widget<Text>(find.text('#Travel')).style!.backgroundColor,
      isNull,
    );
  });

  testWidgets('card shows the excerpt while tags load', (tester) async {
    await tester.pumpWidget(
      muiTestApp(
        SearchResultCard(hit: _hit),
        overrides: [tagCatalogProvider.overrideWithValue(const .loading())],
      ),
    );
    expect(find.text('Excerpt', findRichText: true), findsOneWidget);
    expect(find.text('#Travel'), findsNothing);
  });
}
