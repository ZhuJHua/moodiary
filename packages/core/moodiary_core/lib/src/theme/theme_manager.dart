import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/src/app_logger.dart';
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_core/src/theme/app_color_scheme.dart';
import 'package:moodiary_core/src/theme/font_manager.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Widget _backIcon(BuildContext context) => const Icon(LucideIcons.arrowLeft);

Widget _closeIcon(BuildContext context) => const Icon(LucideIcons.x);

Widget _menuIcon(BuildContext context) => const Icon(LucideIcons.menu);

/// 框架自带 leading/actions 的图标（`AppBar` 隐式返回键、`Scaffold` 抽屉键、
/// `showDateRangePicker` 全屏关闭键）唯一的主题级替换入口 —— 全仓 30+ 个 `AppBar`
/// 都不写 `leading:`，靠这一处把 Material 字形换成 lucide。
/// 命中 builder 会短路掉 `_ActionIcon` 里的平台分支，iOS 的 `arrow_back_ios_new`
/// 与 Android 的 `arrow_back` 就此统一；代价是跳过 Android 专属的 semanticLabel，
/// 但 IconButton 的本地化 tooltip 还在，读屏不受影响。
const ActionIconThemeData _actionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _backIcon,
  closeButtonIconBuilder: _closeIcon,
  drawerButtonIconBuilder: _menuIcon,
  endDrawerButtonIconBuilder: _menuIcon,
);

class ThemeManager {
  ThemeManager._();

  static final ThemeManager instance = ._();

  factory ThemeManager() => instance;

  ThemeData? _lightTheme;

  ThemeData? _darkTheme;

  Map<String, double> wghtAxisMap = {};

  /// 系统壁纸的整套 tonal palette。取不到（iOS、Android 11-、取色失败）即为 null，
  /// [ThemeAccentMode.system] 那一档随之不可选。
  ///
  /// 存整盘而不是存一个种子色：从 `primary.get(40)` 反推会丢掉壁纸的 chroma，
  /// 实测 primary 最大能漂到 ΔE 34（红变褐红）。
  SystemPalettes? _systemPalette;

  /// 只拿到单个系统强调色（非 Android 通道）时的回退种子。
  Color? _systemSeed;

  ThemeData get lightTheme => _lightTheme ?? .light();

  ThemeData get darkTheme => _darkTheme ?? .dark();

  /// 供设置页画那枚系统色块用。
  Color? get systemAccentSeed => _systemPalette == null
      ? _systemSeed
      : Color(_systemPalette!.primary.get(40));

  bool get supportDynamic => _systemPalette != null || _systemSeed != null;

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

    final accent = resolveAccent();
    final lightColorScheme = AppColorScheme.resolve(.light, accent);
    final darkColorScheme = AppColorScheme.resolve(.dark, accent);

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

  /// KV → 强调色来源。system 档在取不到壁纸色时静默回落到无彩，
  /// 不写回 KV —— 换台支持的设备就该自己恢复。
  AccentPalette resolveAccent() {
    final index = MoodiaryKVs.themeAccentMode.get()!;
    final mode = index >= 0 && index < ThemeAccentMode.values.length
        ? ThemeAccentMode.values[index]
        : ThemeAccentMode.neutral;
    return switch (mode) {
      .neutral => const AccentPalette.neutral(),
      .system => switch ((_systemPalette, _systemSeed)) {
        (final palettes?, _) => AccentPalette.system(palettes),
        (_, final seed?) => AccentPalette.seeded(seed),
        _ => const AccentPalette.neutral(),
      },
      .custom => AccentPalette.seeded(
        Color(MoodiaryKVs.themeAccentColor.get()!),
      ),
    };
  }

  /// 编辑器 webview 的配色输入：**解析好的角色色表**，不是种子色。
  ///
  /// 原先下发 (seed, variant) 让 JS 侧用自己那份 material-color-utilities 再算一遍，
  /// 等于两端各跑一套算法 —— [NeutralRamp] 的灰阶覆盖根本传不过去，两边库版本一漂
  /// 还会静默不一致。现在 [ColorScheme] 是唯一真源，JS 只负责铺 CSS 变量。
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
      actionIconTheme: _actionIconTheme,
      // SegmentedButton 选中态的 √（框架默认 Icons.check）。当前 5 处都写了
      // showSelectedIcon: false，这里是给将来不写的那处兜底。
      segmentedButtonTheme: const SegmentedButtonThemeData(
        selectedIcon: Icon(LucideIcons.check),
      ),
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

  /// 只负责拿到系统壁纸的色板；配色生成一律走 [AppColorScheme.resolve]。
  Future<void> findDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        // 就地拆成本仓自己的 SystemPalettes：dynamic_color 的返回类型 CorePalette 在
        // MCU 0.13.0 已废弃，别让它渗进仓里。
        _systemPalette = SystemPalettes(
          primary: corePalette.primary,
          secondary: corePalette.secondary,
          tertiary: corePalette.tertiary,
          neutral: corePalette.neutral,
          neutralVariant: corePalette.neutralVariant,
        );
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain core palette.');
    }

    try {
      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor != null) {
        // 这条通道（Windows / macOS / Linux）只给一个强调色，没有色板可端。
        // 当成普通种子走 tonalSpot —— 只有一个颜色时本来就没有保真度可谈。
        _systemSeed = accentColor;
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain accent color.');
    }

    logger.d('dynamic_color: Dynamic color not detected on this device.');
  }

  (ThemeData, ThemeData) getThemeData() =>
      (_lightTheme ?? .light(), _darkTheme ?? .dark());
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
