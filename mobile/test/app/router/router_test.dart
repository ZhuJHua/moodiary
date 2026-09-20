import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:mui/mui.dart';

void main() {
  group('route tree config', () {
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

  test('params 只放 JSON 标量：go_router 恢复状态时会 json.encode', () {
    const routes = <MoodiaryRouteBase>[
      DiaryRoute(diaryId: 'abc'),
      DiaryRoute(diaryId: 'x', edit: true),
      NewDiaryRoute(categoryId: 'c1'),
      ShareRoute(diaryId: 'd2'),
      LockRoute(lockType: 'pause'),
      DiaryGraphRoute(diaryId: 'd3'),
      ExportFormatRoute(format: 'pdf'),
      AssistantConversationRoute(sessionId: 's1', title: '周三'),
      AssistantConversationRoute(citedDiaryId: 'd1'),
      AssistantProviderEditRoute(id: 'p1', presetId: 'openai'),
    ];

    for (final route in routes) {
      final params = route.params!;
      for (final entry in params.entries) {
        expect(
          entry.value,
          anyOf(isNull, isA<String>(), isA<bool>(), isA<num>()),
          reason: '${route.runtimeType}.${entry.key} 不是 JSON 标量',
        );
      }
      expect(() => json.encode(params), returnsNormally);
    }
  });
}
