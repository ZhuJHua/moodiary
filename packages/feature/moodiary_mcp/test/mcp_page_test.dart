// ignore_for_file: deprecated_member_use

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

class _McpService extends Fake implements McpService {}

class _ServerState extends McpServerController {
  @override
  McpServerState build() =>
      const McpServerState(status: .failed, failure: .unknown);
  void failWithBusyPort() => state = const McpServerState(
    status: .failed,
    port: 54321,
    failure: .portInUse,
  );
}

class _McpKeepAlive extends Fake implements McpKeepAlive {
  @override
  Future<List<KeepAlivePermissionStatus>> statuses() async => [];
}

void main() {
  late _McpService service;

  setUpAll(setupPluralResolvers);
  setUp(() {
    service = _McpService();
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    MoodiaryKVs.mcpEnabled.set(true);
    MoodiaryKVs.mcpAllowLan.set(false);
  });

  for (final locale in AppLocale.values) {
    testWidgets('${locale.name} shows details only for a busy port', (
      tester,
    ) async {
      await tester.runAsync(() => LocaleSettings.setLocale(locale));
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = _ServerState();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            mcpServiceProvider.overrideWithValue(service),
            mcpKeepAliveProvider.overrideWithValue(_McpKeepAlive()),
            mcpServerStateProvider.overrideWith(() => state),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildMuiTheme(brightness: .light),
              locale: locale.flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
                GlobalMuiLocalizations.delegate,
              ],
              builder: (context, child) =>
                  MaterialUiCompatibilityBridge(child: child!),
              home: const McpPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.app.mcpStatusFailedTitle), findsOneWidget);
      expect(find.text(l10n.common.loadFailed), findsNothing);
      final textCount = find.byType(Text).evaluate().length;

      state.failWithBusyPort();
      await tester.pumpAndSettle();

      expect(find.text(l10n.app.mcpStatusFailedTitle), findsOneWidget);
      expect(find.text(l10n.app.mcpPortInUse(port: 54321)), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(textCount + 1));
      expect(tester.takeException(), isNull);
    });
  }
}
