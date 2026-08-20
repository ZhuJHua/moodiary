import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_controller.freezed.dart';
part 'app_settings_controller.g.dart';

/// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme]，
/// 根 widget `ref.watch` 即刷新根节点的 theme / themeMode。
/// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
/// 且主题重建是异步的。
///
/// 语言不在这里：当前语种的真源是 slang 的 `GlobalLocaleState`，根节点通过
/// `TranslationProvider` 拿到它并自动重建。
@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    final (lightTheme, darkTheme) = ThemeManager().getThemeData();
    return AppSettings(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
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
}

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required ThemeData lightTheme,
    required ThemeData darkTheme,
    required ThemeMode themeMode,
  }) = _AppSettings;
}
