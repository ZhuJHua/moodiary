import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:mui/mui.dart';

@lazySingleton
class ThemeManager {
  ThemeManager();

  ThemeData? _lightTheme;

  ThemeData? _darkTheme;

  Map<String, double> wghtAxisMap = {};

  Color? _systemSeed;

  ThemeData get lightTheme =>
      _lightTheme ?? buildMuiTheme(brightness: Brightness.light);

  ThemeData get darkTheme =>
      _darkTheme ?? buildMuiTheme(brightness: Brightness.dark);

  Color? get systemAccentSeed => _systemSeed;

  bool get supportDynamic => _systemSeed != null;

  String? fontFamily;

  String? _activeFontFileName;

  Map<String, double> _unifyFontWeights(Map<String, double> fontWeights) {
    final regular = fontWeights['default'] ?? 400;
    const Map<String, String> nameMapping = {
      "Thin": "Thin",
      "Hairline": "Thin",
      "ExtraLight": "ExtraLight",
      "UltraLight": "ExtraLight",
      "Light": "Light",
      "Normal": "Regular",
      "Regular": "Regular",
      "Book": "Regular",
      "Medium": "Medium",
      "Demibold": "SemiBold",
      "DemiBold": "SemiBold",
      "Semibold": "SemiBold",
      "SemiBold": "SemiBold",
      "Bold": "Bold",
      "Heavy": "Bold",
      "ExtraBold": "ExtraBold",
      "UltraBold": "ExtraBold",
      "Black": "Black",
      "HeavyBlack": "Black",
      "ExtraBlack": "Black",
    };

    final Map<String, double> unified = {};

    for (final entry in fontWeights.entries) {
      final String originalName = entry.key;
      final double weight = entry.value;
      final String unifiedName = nameMapping[originalName] ?? originalName;

      if (unified.containsKey(unifiedName)) {
        final double existingWeight = unified[unifiedName]!;
        unified[unifiedName] =
            (weight - regular).abs() < (existingWeight - regular).abs()
            ? weight
            : existingWeight;
      } else {
        unified[unifiedName] = weight;
      }
    }
    return unified;
  }

  Future<void> buildTheme({ActiveFontDescriptor? customFont}) async {
    await findDynamicColor();

    // 须先归零字体状态，否则切回系统字体时会残留旧家族，须重启才生效
    fontFamily = null;
    _activeFontFileName = null;
    wghtAxisMap = {};

    if (customFont != null) {
      await FontManager.loadFont(
        fontName: customFont.family,
        fontPath: AppFiles.getRealPath('font', customFont.fileName),
      );
      fontFamily = customFont.family;
      _activeFontFileName = customFont.fileName;
      wghtAxisMap = _unifyFontWeights(
        customFont.wghtAxis.cast<String, double>(),
      );
    }

    final accent = resolveAccent();
    final font = MuiFontConfig(family: fontFamily, wghtAxis: wghtAxisMap);

    _lightTheme = buildMuiTheme(
      brightness: Brightness.light,
      accent: accent,
      font: font,
    );
    _darkTheme = buildMuiTheme(
      brightness: Brightness.dark,
      accent: accent,
      font: font,
    );
  }

  ThemeData exportTheme(Brightness brightness) => buildMuiTheme(
    brightness: brightness,
    font: MuiFontConfig(family: fontFamily, wghtAxis: wghtAxisMap),
  );

  MuiAccent resolveAccent() {
    final index = MoodiaryKVs.themeAccentMode.get()!;
    final mode = index >= 0 && index < ThemeAccentMode.values.length
        ? ThemeAccentMode.values[index]
        : ThemeAccentMode.neutral;
    return switch (mode) {
      .neutral => const MuiAccent.neutral(),
      .system => switch (_systemSeed) {
        final seed? => MuiAccent.seeded(seed),
        _ => const MuiAccent.neutral(),
      },
      .custom => MuiAccent.seeded(Color(MoodiaryKVs.themeAccentColor.get()!)),
    };
  }

  Map<String, String> editorRoles(Brightness brightness) {
    final scheme = brightness == .light
        ? lightTheme.colorScheme
        : darkTheme.colorScheme;
    String hex(Color color) =>
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return {
      'surface': hex(scheme.surface),
      'onSurface': hex(scheme.onSurface),
      'onSurfaceVariant': hex(scheme.onSurfaceVariant),
      'surfaceContainerLow': hex(scheme.surfaceContainerLow),
      'surfaceContainer': hex(scheme.surfaceContainer),
      'surfaceContainerHigh': hex(scheme.surfaceContainerHigh),
      'surfaceContainerHighest': hex(scheme.surfaceContainerHighest),
      'primary': hex(scheme.primary),
      'onPrimary': hex(scheme.onPrimary),
      'secondaryContainer': hex(scheme.secondaryContainer),
      'onSecondaryContainer': hex(scheme.onSecondaryContainer),
      'inverseSurface': hex(scheme.inverseSurface),
      'onInverseSurface': hex(scheme.onInverseSurface),
      'outlineVariant': hex(scheme.outlineVariant),
      'error': hex(scheme.error),
    };
  }

  ({String family, String path})? get editorFont {
    final family = fontFamily;
    final fileName = _activeFontFileName;
    if (family == null || fileName == null) return null;
    return (family: family, path: AppFiles.getRealPath('font', fileName));
  }

  Future<void> findDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        _systemSeed = Color(corePalette.primary.get(40));
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain core palette.');
    }

    try {
      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor != null) {
        _systemSeed = accentColor;
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain accent color.');
    }

    logger.d('dynamic_color: Dynamic color not detected on this device.');
  }

  (ThemeData, ThemeData) getThemeData() => (lightTheme, darkTheme);
}

extension ColorExt on Color {
  Brightness get brightness {
    final double relativeLuminance = computeLuminance();

    const double kThreshold = 0.15;
    if ((relativeLuminance + 0.05) * (relativeLuminance + 0.05) > kThreshold) {
      return .light;
    }
    return .dark;
  }
}
