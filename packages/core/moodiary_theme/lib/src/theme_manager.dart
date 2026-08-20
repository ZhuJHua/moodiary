import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:mui/mui.dart';

/// 主题的构建入口。
///
/// 只负责**取参数**（系统取色、自定义字体、KV 读档）并调 mui 的 [buildMuiTheme]；
/// 主题本身是一棵 material 的 [ThemeData]，mui 的那部分挂在它的 `MuiTokens` 扩展上。
class ThemeManager {
  ThemeManager._();

  static final ThemeManager instance = ._();

  factory ThemeManager() => instance;

  ThemeData? _lightTheme;

  ThemeData? _darkTheme;

  Map<String, double> wghtAxisMap = {};

  /// 系统主题色。取不到（iOS、Android 11-、取色失败）即为 null，
  /// [ThemeAccentMode.system] 那一档随之不可选。
  ///
  /// 只存一个种子色：系统档与自定义档共用同一条生成路径，`dynamic_color` 的职责
  /// 到「交出一个颜色」为止。代价是壁纸的 chroma 会按 tone-40 重算，实测 primary
  /// 最大能漂到 ΔE 34（红变褐红）。
  Color? _systemSeed;

  ThemeData get lightTheme =>
      _lightTheme ?? buildMuiTheme(brightness: Brightness.light);

  ThemeData get darkTheme =>
      _darkTheme ?? buildMuiTheme(brightness: Brightness.dark);

  /// 供设置页画那枚系统色块用。
  Color? get systemAccentSeed => _systemSeed;

  bool get supportDynamic => _systemSeed != null;

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

  /// [customFont] 为当前激活的自定义字体，由调用方（FontRepository.getActiveFont）解析注入。
  ///
  /// 收的是**原始描述而不是 `Font`**：那是领域类型，core 不认识它。调用方用
  /// `font.themeDescriptor` 转一下即可。
  Future<void> buildTheme({ActiveFontDescriptor? customFont}) async {
    await findDynamicColor();

    // 每次重建先归零字体状态：从自定义字体切回「系统」时才能立即生效（否则残留旧家族，
    // 须重启才恢复系统字体）。
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
      wghtAxisMap = _unifyFontWeights(customFont.wghtAxis.cast<String, double>());
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

  /// KV → 强调色来源。system 档在取不到壁纸色时静默回落到无彩，
  /// 不写回 KV —— 换台支持的设备就该自己恢复。
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

  /// 编辑器 webview 的配色输入：**解析好的角色色表**，不是种子色。
  ///
  /// 原先下发 (seed, variant) 让 JS 侧用自己那份 material-color-utilities 再算一遍，
  /// 等于两端各跑一套算法 —— 灰阶覆盖根本传不过去，两边库版本一漂还会静默不一致。
  /// 现在 [ColorScheme] 是唯一真源，JS 只负责铺 CSS 变量。
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

  /// 只负责拿到**系统主题色**这一个颜色；配色生成一律走 [resolveColorScheme]。
  Future<void> findDynamicColor() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        // 取 tone-40 当种子。dynamic_color 的返回类型 CorePalette 在 MCU 0.13.0
        // 已废弃，就地拆出一个颜色，别让它渗进仓里。
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
