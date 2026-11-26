import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:mui/mui.dart';

void main() {
  group('route tree config', () {
    testWidgets('unknown location lands on our own error page', (tester) async {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          migrationGateProvider.overrideWithBuild(
            (ref, notifier) => (canStartData: true, canEnterHome: true),
          ),
        ],
      );
      final router = container.read(appRouterProvider)
        ..go('/definitely-not-a-route');
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
    for (final canEnterHome in [false, true]) {
      testWidgets('router follows migration gate: canEnterHome=$canEnterHome', (
        tester,
      ) async {
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            migrationGateProvider.overrideWithBuild(
              (_, _) => (canStartData: true, canEnterHome: canEnterHome),
            ),
          ],
        );
        final router = container.read(appRouterProvider);
        const host = Key('route-parser');
        await tester.pumpWidget(const SizedBox(key: host));
        final context = tester.element(find.byKey(host));
        for (final (path, gated) in [
          (DiaryHomeRoute.path, EditorMigrationRoute.path),
          (DiarySearchRoute.path, EditorMigrationRoute.path),
          (EditorMigrationRoute.path, EditorMigrationRoute.path),
          (LockRoute.path, LockRoute.path),
        ]) {
          final matches = await router.routeInformationParser
              .parseRouteInformationWithDependencies(
                RouteInformation(uri: Uri.parse(path)),
                context,
              );
          expect(matches.error, isNull);
          expect(matches.uri.path, canEnterHome ? path : gated, reason: path);
        }
      });
    }
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
