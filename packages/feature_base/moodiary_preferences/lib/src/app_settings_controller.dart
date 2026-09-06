import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_controller.freezed.dart';
part 'app_settings_controller.g.dart';

@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    final (lightTheme, darkTheme) = getIt<ThemeManager>().getThemeData();
    return AppSettings(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
    );
  }

  Future<void> bumpTheme() async {
    await getIt<ThemeManager>().buildTheme(
      customFont:
          (await getIt<FontRepository>().getActiveFont())?.themeDescriptor,
    );
    final (lightTheme, darkTheme) = getIt<ThemeManager>().getThemeData();
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
