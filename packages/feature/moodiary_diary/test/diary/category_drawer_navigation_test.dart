import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

import '../support/pump.dart';

void main() {
  testWidgets('drawer entries close the drawer and open their routes', (
    tester,
  ) async {
    getIt.registerSingleton(SyncPendingTracker());
    addTearDown(getIt.reset);
    final key = GlobalKey<ScaffoldState>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(key: key, drawer: const CategoryDrawer()),
        ),
        for (final route in const [CategoryManagerRoute(), TagManagerRoute()])
          GoRoute(
            path: route.location,
            builder: (_, _) => Text(route.location),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      muiTestApp(
        Router.withConfig(config: router),
        overrides: [
          orderedCategoriesProvider.overrideWithValue(const .data([])),
          categoryDiaryCountsProvider.overrideWithValue(
            const .data((byCategory: <String, int>{}, total: 9)),
          ),
          tagCatalogProvider.overrideWithValue(
            .data((
              byId: <String, Tag>{},
              usage: [
                for (var index = 0; index < 9; index++)
                  (name: 'Tag $index', count: 1, lastUsed: null),
              ],
            )),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    for (final (entry, route) in [
      (find.byTooltip('管理分类'), const CategoryManagerRoute()),
      (find.byTooltip('管理标签'), const TagManagerRoute()),
      (find.text('更多 1'), const TagManagerRoute()),
    ]) {
      key.currentState!.openDrawer();
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.settings), findsNothing);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text(route.location), findsOneWidget);
      expect(key.currentState!.isDrawerOpen, isFalse);
      router.pop();
      await tester.pumpAndSettle();
    }
  });
}
