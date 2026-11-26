import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_tile.dart';
import 'package:mui/mui.dart';

import '../sync_test_harness.dart';

void main() {
  setUp(() async {
    KVStore.installForTesting(MemoryKVStorage());
    SecureKVStore.installForTesting(MemorySecureKVStorage());
    addTearDown(() {
      SecureKVStore.resetForTesting();
      KVStore.resetForTesting();
    });
    await LocaleSettings.setLocale(AppLocale.zh);
  });

  testWidgets(
    'submit and remove keep the key sheet open while a poll holds the guard',
    (tester) async {
      final backend = FakeRemoteBackend();
      final pollLock = Completer<void>();
      final theme = buildMuiTheme(brightness: .light);
      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [activeSyncBackendProvider.overrideWithValue(backend)],
          child: TranslationProvider(
            child: MuiTheme(
              data: theme,
              child: MaterialApp(
                theme: theme,
                locale: const Locale('zh'),
                builder: FlutterSmartDialog.init(),
                localizationsDelegates: const [
                  ...GlobalMaterialLocalizations.delegates,
                  GlobalMuiLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) {
                      capturedContext = context;
                      capturedRef = ref;
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        showUserKeySheet(
          capturedContext,
          capturedRef,
          UserKeySheetMode.on,
          backend,
        ),
      );
      await tester.pumpAndSettle();

      // Background poll acquires the guard while the user is typing.
      final holdPoll = capturedRef
          .read(syncOperationGuardProvider)
          .tryRun(() => pollLock.future);
      expect(capturedRef.read(syncOperationGuardProvider).isBusy, isTrue);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'new-passphrase');
      await tester.enterText(fields.at(1), 'new-passphrase');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.sync.keyChangeAction),
      );
      await tester.pump();

      // Sheet stays open with user's typed text intact instead of silently discarding.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        tester.widget<TextField>(fields.at(0)).controller?.text,
        'new-passphrase',
      );

      // Remove also refuses to dismiss while busy.
      await tester.tap(find.byType(MDangerRow));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(l10n.sync.statusRunning), findsWidgets);

      pollLock.complete();
      await holdPoll;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
}
