// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

class _McpService extends Fake implements McpService {
  @override
  final state = ValueNotifier(
    const McpServerState(status: .failed, failure: .unknown),
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
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    getIt.registerSingleton<McpService>(service);
    getIt.registerSingleton<McpKeepAlive>(_McpKeepAlive());
    MoodiaryKVs.mcpEnabled.set(true);
    MoodiaryKVs.mcpAllowLan.set(false);
  });
  tearDown(() async {
    service.state.dispose();
    await getIt.reset();
  });

  for (final locale in AppLocale.values) {
    testWidgets('${locale.name} shows details only for a busy port', (
      tester,
    ) async {
      await tester.runAsync(() => LocaleSettings.setLocale(locale));
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        TranslationProvider(
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
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.app.mcpStatusFailedTitle), findsOneWidget);
      expect(find.text(l10n.common.loadFailed), findsNothing);
      final textCount = find.byType(Text).evaluate().length;

      service.state.value = const McpServerState(
        status: .failed,
        port: 54321,
        failure: .portInUse,
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.app.mcpStatusFailedTitle), findsOneWidget);
      expect(find.text(l10n.app.mcpPortInUse(port: 54321)), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(textCount + 1));
      expect(tester.takeException(), isNull);
    });
  }
}
