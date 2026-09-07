import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:mui/mui.dart';

void main() {
  group('route tree config', () {
    testWidgets('mobile tree builds a valid GoRouter', (tester) async {
      expect(
        () => GoRouter(routes: buildMobileRoutes(), initialLocation: '/'),
        returnsNormally,
      );
    });

    testWidgets('unknown location lands on our own error page', (tester) async {
      final router = createMobileRouter(
        initialLocation: '/definitely-not-a-route',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp.router(
            theme: buildMuiTheme(brightness: Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorPage), findsOneWidget);
      expect(find.text('/definitely-not-a-route'), findsOneWidget);
    });
  });

  group('migration gate redirect', () {
    tearDown(() => EditorMigrationService.requiresMigration = false);

    test('迁移未完成时除锁屏与迁移页外一律重定向', () {
      EditorMigrationService.requiresMigration = true;
      expect(migrationGateRedirect('/'), EditorMigrationRoute.path);
      expect(
        migrationGateRedirect(DiarySearchRoute.path),
        EditorMigrationRoute.path,
      );
      expect(migrationGateRedirect(EditorMigrationRoute.path), isNull);
      expect(migrationGateRedirect(LockRoute.path), isNull);
    });

    test('无待迁移时不重定向', () {
      EditorMigrationService.requiresMigration = false;
      expect(migrationGateRedirect('/'), isNull);
    });
  });

  group('route params contract', () {
    test('DiaryRoute', () {
      const route = DiaryRoute(diaryId: 'abc');
      expect(route.location, '/diary');
      expect(route.params, {'diary_id': 'abc', 'edit': false});
      expect(const DiaryRoute(diaryId: 'x', edit: true).params, {
        'diary_id': 'x',
        'edit': true,
      });
    });

    test('NewDiaryRoute always starts in edit', () {
      expect(const NewDiaryRoute().location, '/diary-new');
      expect(const NewDiaryRoute(categoryId: 'c1').params, {
        'category_id': 'c1',
        'edit': true,
      });
    });

    test('ShareRoute', () {
      expect(const ShareRoute().location, '/share');
      expect(const ShareRoute(diaryId: 'd2').params, {'diary_id': 'd2'});
    });

    test('LockRoute', () {
      expect(const LockRoute().location, '/lock');
      expect(const LockRoute(lockType: 'pause').params, {'lock_type': 'pause'});
    });

    test('no-param routes carry no extra', () {
      expect(const DiaryHomeRoute().location, '/');
      expect(const RecycleRoute().location, '/recycle');
      expect(const DiarySearchRoute().location, '/search');
      expect(const FontRoute().location, '/setting/font');
      expect(const AccentRoute().location, '/setting/accent');
      expect(const RecycleRoute().params, isNull);
    });

    test('AssistantConversationRoute', () {
      expect(
        const AssistantConversationRoute().location,
        '/assistant/conversation',
      );
      expect(const AssistantConversationRoute(sessionId: 's1').params, {
        'session_id': 's1',
      });
    });
  });
}
