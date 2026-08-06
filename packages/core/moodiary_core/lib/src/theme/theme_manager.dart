import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/src/values/colors.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_core/src/theme/font_manager.dart';
import 'package:moodiary_core/src/app_logger.dart';

class ThemeManager {
  ThemeManager._();

  static final ThemeManager instance = ._();

  factory ThemeManager() => instance;

  ThemeData? _lightTheme;

  ThemeData? _darkTheme;

  Map<String, double> wghtAxisMap = {};

  ColorScheme? lightDynamic;

  ColorScheme? darkDynamic;

  /// 系统取色种子，供把配色生成下放到 webview 侧时复用。
  Color? _dynamicSeed;

  ThemeData get lightTheme => _lightTheme ?? .light();

  ThemeData get darkTheme => _darkTheme ?? .dark();

  bool get supportDynamic => lightDynamic != null && darkDynamic != null;

  String? fontFamily;

  /// 当前激活自定义字体的落库文件名（含后缀）；供 [editorFont] 拼磁盘路径给 webview 编辑器。
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

  TextTheme _applyFontVariations(TextTheme baseTheme) {
    final regularFontWeight = wghtAxisMap['Regular'] ?? 400;
    final mediumFontWeight = wghtAxisMap['Medium'] ?? 500;
    final semiBoldFontWeight = wghtAxisMap['SemiBold'] ?? 600;
    final boldFontWeight = wghtAxisMap['Bold'] ?? 700;
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w700,
        fontVariations: [FontVariation('wght', boldFontWeight)],
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w600,
        fontVariations: [FontVariation('wght', semiBoldFontWeight)],
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w600,
        fontVariations: [FontVariation('wght', semiBoldFontWeight)],
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: .w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
    );
  }

  /// [customFont] 为当前激活的自定义字体，由调用方（FontRepository.getActiveFont）解析注入。
  Future<void> buildTheme({Font? customFont}) async {
    await findDynamicColor();

    var color = MoodiaryKVs.color.get();

    // 首次启动未设配色：支持动态取色用 -1，否则默认 0。
    if (color == null) {
      if (supportDynamic) {
        MoodiaryKVs.color.set(-1);
        color = -1;
      } else {
        MoodiaryKVs.color.set(0);
        color = 0;
      }
    }

    final isDynamic = color == -1 && supportDynamic;

    late final normalColor =
        AppColor.themeColorList[(color! >= 0 &&
                color < AppColor.themeColorList.length)
            ? color
            : 0];

    final lightColorScheme = isDynamic
        ? lightDynamic!
        : buildColorScheme(normalColor, .light, color);

    final darkColorScheme = isDynamic
        ? darkDynamic!
        : buildColorScheme(normalColor, .dark, color);

    // 每次重建先归零字体状态：从自定义字体切回「系统」时才能立即生效（否则残留旧家族，
    // 须重启才恢复系统字体）。
    fontFamily = null;
    _activeFontFileName = null;
    wghtAxisMap = {};

    if (customFont != null) {
      await FontManager.loadFont(
        fontName: customFont.fontFamily,
        fontPath: AppFiles.getRealPath('font', customFont.fontFileName),
      );
      fontFamily = customFont.fontFamily;
      _activeFontFileName = customFont.fontFileName;
      wghtAxisMap = _unifyFontWeights(
        customFont.fontWghtAxisMap.cast<String, double>(),
      );
    }

    final lightTextTheme = buildTextTheme(lightColorScheme);
    final darkTextTheme = buildTextTheme(darkColorScheme);

    final lightTypography = buildTypography(lightColorScheme);
    final darkTypography = buildTypography(darkColorScheme);

    _lightTheme = buildThemeData(
      lightColorScheme,
      lightTextTheme,
      lightTypography,
      fontFamily,
      wghtAxisMap,
      .light,
    );
    _darkTheme = buildThemeData(
      darkColorScheme,
      darkTextTheme,
      darkTypography,
      fontFamily,
      wghtAxisMap,
      .dark,
    );
  }

  ColorScheme buildColorScheme(
    Color seedColor,
    Brightness brightness,
    int color,
  ) {
    var dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;
    if (color == 0) {
      dynamicSchemeVariant = .monochrome;
    }
    if (color == -1) {
      dynamicSchemeVariant = .tonalSpot;
    }
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: dynamicSchemeVariant,
    ).harmonized();
  }

  /// 当前配色的「种子色 + 变体」，供 webview 侧用 material-color-utilities 重建配色。
  /// 变体判定务必与 [buildColorScheme] 一致：`color == 0` monochrome，其余 tonalSpot。
  ({Color seed, String variant}) get editorSeed {
    final color = MoodiaryKVs.color.get() ?? (supportDynamic ? -1 : 0);
    if (color == -1 && supportDynamic && _dynamicSeed != null) {
      return (seed: _dynamicSeed!, variant: 'tonalSpot');
    }
    final index = (color >= 0 && color < AppColor.themeColorList.length)
        ? color
        : 0;
    return (
      seed: AppColor.themeColorList[index],
      variant: color == 0 ? 'monochrome' : 'tonalSpot',
    );
  }

  /// 当前激活的自定义字体（家族名 + 字体文件磁盘路径），供 webview 编辑器用 @font-face 加载
  /// 同一字体；未设置自定义字体（系统字体）时返回 null。依赖 [buildTheme] 已解析当前字体。
  ({String family, String path})? get editorFont {
    final family = fontFamily;
    final fileName = _activeFontFileName;
    if (family == null || fileName == null) return null;
    return (family: family, path: AppFiles.getRealPath('font', fileName));
  }

  Typography buildTypography(ColorScheme colorScheme) {
    return .material2021(
      platform: defaultTargetPlatform,
      colorScheme: colorScheme,
    );
  }

  TextTheme buildTextTheme(ColorScheme colorScheme) {
    final typography = buildTypography(colorScheme);
    final textTheme = colorScheme.brightness == .light
        ? typography.black
        : typography.white;
    return _applyFontVariations(textTheme);
  }

  ThemeData buildThemeData(
    ColorScheme colorScheme,
    TextTheme textTheme,
    Typography typography,
    String? fontFamily,
    Map<String, double> wghtAxisMap,
    Brightness brightness,
  ) {
    return ThemeData(
      colorScheme: colorScheme,
      materialTapTargetSize: .padded,
      // 内容滚到顶栏下方时不再有任何视觉变化。要关的是**两件事**，缺一个都还会跳：
      //   1. 底色：滚动态取的是 `colorScheme.surfaceContainer` 而非 `surface`
      //      （app_bar.dart 的 scrolledUnderBackground）——把 backgroundColor 钉住，
      //      两种状态就都用它；
      //   2. 阴影：scrolledUnderElevation 默认 3，会投出一道影子。
      // 注意**不是**改 surfaceTintColor —— Flutter 3.44 的 M3 默认值本来就是
      // transparent（_AppBarDefaultsM3），设它等于没设（实测两者渲染结果完全一致）。
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      // 兜住尚未迁到 showMoodiaryAlert 的原生弹窗（选择列表、进度、日期选择器），
      // 让它们的圆角/标题/遮罩与新组件一致 —— M3 默认是 28 圆角 + headlineSmall(24sp)
      // + black54，是全仓唯一不遵守 AppBorderRadius 的一处。
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        elevation: 8,
        barrierColor: colorScheme.scrim.withValues(alpha: 0.32),
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.xLargeBorderRadius,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: .w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: .all(colorScheme.secondary.withValues(alpha: 0.4)),
        thickness: .all(4.0),
        radius: const .circular(2.0),
        mainAxisMargin: 24.0,
      ),
      brightness: brightness,
      fontFamily: fontFamily,
      typography: typography,
      textTheme: _applyFontVariations(textTheme),
    );
  }

  Future<void> findDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();

      if (corePalette != null) {
        final seedColor = Color(corePalette.primary.get(40));

        _dynamicSeed = seedColor;
        lightDynamic = buildColorScheme(seedColor, .light, -1);
        darkDynamic = buildColorScheme(seedColor, .dark, -1);
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain core palette.');
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();

      if (accentColor != null) {
        _dynamicSeed = accentColor;
        lightDynamic = buildColorScheme(accentColor, .light, -1);
        darkDynamic = buildColorScheme(accentColor, .dark, -1);
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain accent color.');
    }

    logger.d('dynamic_color: Dynamic color not detected on this device.');
  }

  (ThemeData, ThemeData) getThemeData() {
    final isDynamic = supportDynamic && MoodiaryKVs.color.get() == -1;
    if (isDynamic) {
      return (
        _lightTheme?.copyWith(
              colorScheme: lightDynamic,
              textTheme: buildTextTheme(lightDynamic!),
              typography: buildTypography(lightDynamic!),
            ) ??
            .light(),
        _darkTheme?.copyWith(
              colorScheme: darkDynamic,
              textTheme: buildTextTheme(darkDynamic!),
              typography: buildTypography(darkDynamic!),
            ) ??
            .dark(),
      );
    } else {
      return (_lightTheme ?? .light(), _darkTheme ?? .dark());
    }
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

extension ColorExt2 on BuildContext {
  Color adaptiveColor(Color color) {
    if (!isDarkMode) return color;

    final hsl = HSLColor.fromColor(color);
    final inverted = hsl.withLightness(1.0 - hsl.lightness);
    return inverted.toColor();
  }
}
