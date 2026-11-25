import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

void main() {
  for (final pauseLock in [false, true]) {
    testWidgets('startup completes with pause lock = $pauseLock', (
      tester,
    ) async {
      final startup = Completer<void>();
      var resumes = 0;
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      addTearDown(getIt.reset);
      MoodiaryKVs.legacyAbandonJournal.set('interrupted');
      expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.abandoning);
      final router = GoRouter(
        initialLocation: EditorMigrationRoute.path,
        routes: [
          ...migrationRoutes(
            resumeStartup: () {
              resumes++;
              return startup.future;
            },
          ),
          GoRoute(
            path: DiaryHomeRoute.path,
            builder: (_, _) => const Text('home'),
          ),
          GoRoute(
            path: LockRoute.path,
            builder: (context, _) => TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('unlock'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildMuiTheme(brightness: .light),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      MoodiaryKVs.dbEngineMigrated.set(true);
      MoodiaryKVs.legacyAbandonJournal.remove();
      await tester.tap(find.text(l10n.editor.migrationRetry));
      await tester.pump();
      expect(resumes, 1);
      if (pauseLock) {
        unawaited(router.pushRoute<void>(const LockRoute(lockType: 'pause')));
        await tester.pumpAndSettle();
      }
      startup.complete();
      await tester.pumpAndSettle();
      if (pauseLock) {
        expect(find.text('unlock'), findsOneWidget);
        expect(find.text('home'), findsNothing);
        await tester.tap(find.text('unlock'));
        await tester.pumpAndSettle();
      }
      expect(find.text('home'), findsOneWidget);
      expect(resumes, 1);
    });
  }
}
