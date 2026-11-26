import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

class _Exporter implements LegacyDataExporter {
  const _Exporter(this.archive);

  final File archive;

  @override
  Future<LegacyExportSummary> inspect() async =>
      (databaseBytes: 1, mediaCount: 0, mediaBytes: 0);

  @override
  Future<String> export({
    required void Function(int, int) onProgress,
    required bool Function() isCancelled,
  }) async => archive.path;
}

void main() {
  late File archive;
  setUpAll(() {
    final root = Directory.systemTemp.createTempSync('legacy-backup-share-');
    addTearDown(() => root.deleteSync(recursive: true));
    PlatformService.get().applicationSupportPath = root.path;
    File('${root.path}/database/default.isar')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    archive = File('${root.path}/backup.zip')..writeAsBytesSync([1]);
  });

  for (final result in [
    'files',
    '',
    'dev.fluttercommunity.plus/share/unavailable',
  ]) {
    testWidgets('requires manual confirmation after share result "$result"', (
      tester,
    ) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      expect(
        await tester.runAsync(LegacyDatabaseGuard.probe),
        LegacyDatabaseState.pending,
      );
      final shareResult = Completer<String>();
      final messenger = tester.binding.defaultBinaryMessenger;
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(channel, (call) {
        expect(call.method, 'share');
        expect(call.arguments['paths'], [archive.path]);
        expect(call.arguments['mimeTypes'], ['application/zip']);
        return shareResult.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            legacyDataExporterProvider.overrideWithValue(_Exporter(archive)),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildMuiTheme(brightness: .light),
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
                GlobalMuiLocalizations.delegate,
              ],
              home: EditorMigrationPage(resumeStartup: () async {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final generate = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.editor.legacyExport),
      );
      await tester.runAsync(generate.onPressed! as Future<void> Function());
      await tester.pumpAndSettle();
      final share = find.widgetWithText(FilledButton, l10n.editor.legacyShare);
      final confirmation = find.widgetWithText(
        FilledButton,
        l10n.editor.legacyShareConfirmed,
      );
      expect(find.byType(FilledButton), findsOneWidget);
      // 唯一的描边按钮是"放弃旧数据"。
      expect(
        find.widgetWithText(OutlinedButton, l10n.editor.legacyAbandon),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(confirmation, findsNothing);
      await tester.tap(share);
      await tester.pump();
      expect(confirmation, findsNothing);
      shareResult.complete(result);
      await tester.pumpAndSettle();
      expect(find.text(l10n.editor.legacyGenerated), findsOneWidget);
      if (result.isEmpty) {
        expect(confirmation, findsNothing);
        return;
      }
      expect(confirmation, findsOneWidget);
      // 分享过后分享降为描边按钮，可以再次分享。
      expect(
        find.widgetWithText(OutlinedButton, l10n.editor.legacyShare),
        findsOneWidget,
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pumpAndSettle();
      expect(find.text(l10n.editor.legacySaved), findsOneWidget);
      expect(
        find.text(l10n.editor.legacySharedVerified(name: 'backup.zip')),
        findsOneWidget,
      );
    });
  }
}
