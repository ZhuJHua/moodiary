import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_models/moodiary_models.dart';
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

  group('location encoding contract', () {
    test('DiaryRoute', () {
      expect(
        DiaryRoute(
          type: DiaryType.markdown.routeQuery,
          diaryId: 'abc',
        ).location,
        '/diary/abc?type=markdown',
      );
      expect(
        DiaryRoute(
          type: DiaryType.richText.routeQuery,
          diaryId: 'x',
          edit: true,
        ).location,
        '/diary/x?type=rich-text&edit=true',
      );
    });

    test('NewDiaryRoute', () {
      expect(
        NewDiaryRoute(type: DiaryType.tiptap.routeQuery).location,
        '/diary-new?type=tiptap',
      );
      expect(
        NewDiaryRoute(type: DiaryType.markdown.routeQuery).location,
        '/diary-new?type=markdown',
      );
    });

    test('ShareRoute', () {
      expect(const ShareRoute().location, '/share');
      expect(const ShareRoute(diaryId: 'd2').location, '/share?diary-id=d2');
    });

    test('LockRoute', () {
      expect(const LockRoute().location, '/lock');
      expect(
        const LockRoute(lockType: 'pause').location,
        '/lock?lock-type=pause',
      );
    });

    test('no-param routes expose their path as location', () {
      expect(const DiaryHomeRoute().location, '/');
      expect(const RecycleRoute().location, '/recycle');
      expect(const DiarySearchRoute().location, '/search');
      expect(const FontRoute().location, '/setting/font');
      expect(const AccentRoute().location, '/setting/accent');
    });

    test('AssistantConversationRoute', () {
      expect(
        const AssistantConversationRoute().location,
        '/assistant/conversation',
      );
      expect(
        const AssistantConversationRoute(sessionId: 's1').location,
        '/assistant/conversation?session-id=s1',
      );
    });
  });
}
