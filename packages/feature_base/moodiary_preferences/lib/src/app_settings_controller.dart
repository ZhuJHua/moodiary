import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'font_preferences.dart';

part 'app_settings_controller.freezed.dart';
part 'app_settings_controller.g.dart';

@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  int _revision = 0;

  @override
  AppSettings build() => AppSettings(
    lightTheme: buildMuiTheme(brightness: Brightness.light),
    darkTheme: buildMuiTheme(brightness: Brightness.dark),
    themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
    systemAccentSeed: null,
    fontConfig: const MuiFontConfig(),
    editorFont: null,
  );

  void initFromBuilt(BuiltTheme built, {required ThemeMode themeMode}) {
    _revision++;
    state = AppSettings(
      lightTheme: built.lightTheme,
      darkTheme: built.darkTheme,
      themeMode: themeMode,
      systemAccentSeed: built.systemAccentSeed,
      fontConfig: built.fontConfig,
      editorFont: built.editorFont,
    );
  }

  Future<void> bumpTheme() async {
    final operationRef = ref;
    final revision = ++_revision;
    final builder = ref.read(themeBuilderProvider);
    final font = await ref.read(fontRepositoryProvider).getActiveFont();
    if (!operationRef.mounted || revision != _revision) return;
    final built = await builder.buildTheme(customFont: font?.themeDescriptor);
    if (!operationRef.mounted || revision != _revision) return;
    initFromBuilt(
      built,
      themeMode: ThemeMode.values[MoodiaryKVs.themeMode.get()!],
    );
  }
}

@freezed
abstract class AppSettings with _$AppSettings {
  const AppSettings._();

  bool get supportDynamic => systemAccentSeed != null;
  ThemeData exportTheme(Brightness brightness) =>
      buildMuiTheme(brightness: brightness, font: fontConfig);

  const factory AppSettings({
    required ThemeData lightTheme,
    required ThemeData darkTheme,
    required ThemeMode themeMode,
    required Color? systemAccentSeed,
    required MuiFontConfig fontConfig,
    required ({String family, String path})? editorFont,
  }) = _AppSettings;
}
