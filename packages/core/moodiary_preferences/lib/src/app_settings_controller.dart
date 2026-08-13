import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_controller.freezed.dart';
part 'app_settings_controller.g.dart';

/// 初始 locale，必须在 `main()` 里 `overrideWithValue` 注入（[findSystemLocale]
/// 已在 `_initSystem` 解析过，这里复用结果而不再 await）。
final appInitialLocaleProvider = Provider<Locale>(
  (ref) => throw UnimplementedError('appInitialLocaleProvider 必须在 main 中覆盖'),
);

/// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme] / [bumpLocale]，
/// 根 widget `ref.watch` 即刷新根节点的 theme / locale / themeMode。
/// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
/// 且主题 / locale 重建是异步的。
@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    final (lightTheme, darkTheme) = ThemeManager().getThemeData();
    return AppSettings(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
      locale: ref.read(appInitialLocaleProvider),
    );
  }

  Future<void> bumpTheme() async {
    await ThemeManager().buildTheme(
      customFont: await FontRepository.get().getActiveFont(),
    );
    final (lightTheme, darkTheme) = ThemeManager().getThemeData();
    state = state.copyWith(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
    );
  }

  Future<void> bumpLocale() async {
    final lang = MoodiaryKVs.language.get() ?? 'system';
    final String code;
    if (lang == 'system') {
      final systemLocale = await findSystemLocale();
      code = systemLocale.contains('_')
          ? systemLocale.split('_').first
          : systemLocale;
    } else {
      code = lang;
    }
    Intl.defaultLocale = code;
    state = state.copyWith(locale: Locale(code));
  }
}

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required ThemeData lightTheme,
    required ThemeData darkTheme,
    required ThemeMode themeMode,
    required Locale locale,
  }) = _AppSettings;
}
