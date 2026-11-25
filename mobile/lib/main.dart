import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mobile/app/boot_failure_page.dart';
import 'package:moodiary_mobile/app/build_badge.dart';
import 'package:moodiary_mobile/app/di/app_startup.dart';
import 'package:moodiary_mobile/app/di/overrides.dart';
import 'package:moodiary_mobile/app/licenses.dart';
import 'package:moodiary_mobile/app/lifecycle/app_lock_observer.dart';
import 'package:moodiary_mobile/app/lifecycle/reminder_navigation.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.e(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.f('Error', error: error, stackTrace: stack);
    return true;
  };

  registerThirdPartyLicenses();

  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: buildMobilePortOverrides(),
      child: const AppStartupWidget(),
    ),
  );
}

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(appStartupProvider)
      .when(
        loading: () => const _StartupPlaceholder(),
        error: (error, stack) => BuildBadge(
          child: BootFailurePage(error: error, stackTrace: stack),
        ),
        data: (_) => MGlassApp(
          child: BuildBadge(
            child: TranslationProvider(
              child: const _EagerInitialization(child: Moodiary()),
            ),
          ),
        ),
      );
}

class _StartupPlaceholder extends StatelessWidget {
  const _StartupPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStartupProvider);
    ref.watch(autoSyncWatcherProvider);
    ref.watch(embedQueueWatcherProvider);
    return child;
  }
}

class Moodiary extends ConsumerWidget {
  const Moodiary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final palette = ref.watch(kvValueProvider(MoodiaryKVs.moodPalette));
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.common.appName,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final brightness = switch (settings.themeMode) {
          .light => Brightness.light,
          .dark => Brightness.dark,
          .system => MediaQuery.platformBrightnessOf(context),
        };
        return AnnotatedRegion(
          value: systemOverlayStyleOf(brightness),
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(
            child: MGlassPrivacyOverlay(
              isEnabled: () => MoodiaryKVs.backendPrivacy.get() == true,
              child: MoodPaletteScope(
                palette: MoodPalette.fromName(palette),
                child: ReminderNavigation(
                  child: AppLockObserver(
                    child: FlutterSmartDialog.init()(context, child!),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: TranslationProvider.of(context).flutterLocale,
      themeMode: settings.themeMode,
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        GlobalMuiLocalizations.delegate,
      ],
      supportedLocales: AppLocaleUtils.supportedLocales,
    );
  }
}
