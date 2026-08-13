import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/app/router/route_error_page.dart';
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
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

    // 裸 GoRoute 的 `builder:` 会被 go_router 包成 NoTransitionPage：它认 legacy
    // MaterialApp，认不出我们挂的 material_ui 那个，探测落到 WidgetsApp 分支。
    // 详见 moodiary_router 的 route_page.dart。
    test('every route carries a pageBuilder', () {
      final bare = <String>[];
      void walk(List<RouteBase> routes) {
        for (final route in routes) {
          if (route is GoRoute &&
              !route.redirectOnly &&
              route.pageBuilder == null) {
            bare.add(route.path);
          }
          walk(route.routes);
        }
      }

      walk(buildMobileRoutes());
      expect(bare, isEmpty, reason: '这些路由请改用 MoodiaryGoRoute');
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
