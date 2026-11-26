import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

import 'app_color_scheme.dart';
import 'font_manager.dart';

class BuiltTheme {
  const BuiltTheme({
    required this.lightTheme,
    required this.darkTheme,
    required this.systemAccentSeed,
    required this.fontConfig,
    required this.editorFont,
  });

  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final Color? systemAccentSeed;
  final MuiFontConfig fontConfig;
  final ({String family, String path})? editorFont;

  bool get supportDynamic => systemAccentSeed != null;
  ThemeData exportTheme(Brightness brightness) =>
      buildMuiTheme(brightness: brightness, font: fontConfig);
}

class ThemeBuilder {
  Future<Color?>? _systemSeed;

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

  Future<BuiltTheme> buildTheme({ActiveFontDescriptor? customFont}) async {
    final seed = await (_systemSeed ??= _findDynamicColor());
    final editorFont = customFont == null
        ? null
        : (
            family: customFont.family,
            path: AppFiles.getRealPath('font', customFont.fileName),
          );
    if (editorFont != null) {
      await FontManager.loadFont(
        fontName: editorFont.family,
        fontPath: editorFont.path,
      );
    }
    final font = MuiFontConfig(
      family: customFont?.family,
      wghtAxis: customFont == null
          ? const {}
          : Map.unmodifiable(
              _unifyFontWeights(customFont.wghtAxis.cast<String, double>()),
            ),
    );
    final accent = _resolveAccent(seed);
    return BuiltTheme(
      lightTheme: buildMuiTheme(
        brightness: Brightness.light,
        accent: accent,
        font: font,
      ),
      darkTheme: buildMuiTheme(
        brightness: Brightness.dark,
        accent: accent,
        font: font,
      ),
      systemAccentSeed: seed,
      fontConfig: font,
      editorFont: editorFont,
    );
  }

  MuiAccent _resolveAccent(Color? seed) {
    final index = MoodiaryKVs.themeAccentMode.get()!;
    final mode = index >= 0 && index < ThemeAccentMode.values.length
        ? ThemeAccentMode.values[index]
        : ThemeAccentMode.neutral;
    return switch (mode) {
      .neutral => const MuiAccent.neutral(),
      .system => switch (seed) {
        final seed? => MuiAccent.seeded(seed),
        _ => const MuiAccent.neutral(),
      },
      .custom => MuiAccent.seeded(Color(MoodiaryKVs.themeAccentColor.get()!)),
    };
  }

  Future<Color?> _findDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        return Color(corePalette.primary.get(40));
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain core palette.');
    }

    try {
      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor != null) {
        return accentColor;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain accent color.');
    }

    logger.d('dynamic_color: Dynamic color not detected on this device.');
    return null;
  }
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
