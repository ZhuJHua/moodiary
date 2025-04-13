import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/internal.dart';
import 'package:get/get.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/font_util.dart';
import 'package:moodiary/utils/log_util.dart';

class ThemeUtil {
  ThemeUtil._();

  static final ThemeUtil instance = ThemeUtil._();

  factory ThemeUtil() => instance;

  // 亮色模式的主题缓存
  ThemeData? _lightTheme;

  // 暗色模式的主题缓存
  ThemeData? _darkTheme;

  // 字体的字重缓存
  Map<String, double> wghtAxisMap = {};

  // 动态配色的浅色主题
  ColorScheme? lightDynamic;

  // 动态配色的深色主题
  ColorScheme? darkDynamic;

  ThemeData get lightTheme => _lightTheme ?? ThemeData.light();

  ThemeData get darkTheme => _darkTheme ?? ThemeData.dark();

  bool get supportDynamic => lightDynamic != null && darkDynamic != null;

  // 字体的名称缓存
  String? fontFamily;

  Map<String, double> _unifyFontWeights(Map<String, double> fontWeights) {
    // 标准
    final regular = fontWeights['default'] ?? 400;
    // 名称映射表：将各种名称映射到统一的标准名称
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
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation('wght', boldFontWeight)],
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation('wght', semiBoldFontWeight)],
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation('wght', semiBoldFontWeight)],
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontVariations: [FontVariation('wght', mediumFontWeight)],
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontVariations: [FontVariation('wght', regularFontWeight)],
      ),
    );
  }

  /// 构建主题
  /// 第一个返回值为亮色主题，第二个为暗色主题
  Future<void> buildTheme() async {
    await findDynamicColor();

    var color = PrefUtil.getValue<int>('color');

    // 如果是首次打开软件，还没有设置配色，检查是否支持动态配色
    if (color == null) {
      // 如果支持动态配色，设置为动态配色
      if (supportDynamic) {
        PrefUtil.setValue('color', -1);
        color = -1;
      } else {
        // 否则设置为默认配色
        PrefUtil.setValue('color', 0);
        color = 0;
      }
    }

    final isDynamic = color == -1 && supportDynamic;

    late final normalColor =
        AppColor.themeColorList[(color! >= 0 &&
                color < AppColor.themeColorList.length)
            ? color
            : 0];

    final lightColorScheme =
        isDynamic
            ? lightDynamic!
            : buildColorScheme(normalColor, Brightness.light, color);

    final darkColorScheme =
        isDynamic
            ? darkDynamic!
            : buildColorScheme(normalColor, Brightness.dark, color);

    final customFont = PrefUtil.getValue<String>('customFont');

    // 加载自定义字体
    if (customFont.isNotNullOrBlank) {
      final font = await IsarUtil.getFontByFontFamily(customFont!);
      if (font != null) {
        await FontUtil.loadFont(
          fontName: font.fontFamily,
          fontPath: FileUtil.getRealPath('font', font.fontFileName),
        );
        fontFamily = font.fontFamily;
        wghtAxisMap = _unifyFontWeights(
          font.fontWghtAxisMap.cast<String, double>(),
        );
      }
    } else if (Platform.isWindows) {
      fontFamily = 'Microsoft Yahei UI';
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
      Brightness.light,
    );
    _darkTheme = buildThemeData(
      darkColorScheme,
      darkTextTheme,
      darkTypography,
      fontFamily,
      wghtAxisMap,
      Brightness.dark,
    );
  }

  // 辅助函数：构建 colorScheme
  ColorScheme buildColorScheme(
    Color seedColor,
    Brightness brightness,
    int color,
  ) {
    // 默认的配色生成算法，这个会生成低饱和度的配色
    var dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;
    if (color == 0) {
      dynamicSchemeVariant = DynamicSchemeVariant.monochrome;
    }
    if (color == -1) {
      dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;
    }
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: dynamicSchemeVariant,
    ).harmonized();
  }

  // 辅助函数：构建 typography
  Typography buildTypography(ColorScheme colorScheme) {
    return Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: colorScheme,
    );
  }

  TextTheme buildTextTheme(ColorScheme colorScheme) {
    final typography = buildTypography(colorScheme);
    final textTheme =
        colorScheme.brightness == Brightness.light
            ? typography.black
            : typography.white;
    return _applyFontVariations(textTheme);
  }

  // 辅助函数：构建 ThemeData
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
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(colorScheme.secondary),
        thickness: WidgetStateProperty.all(4.0),
        radius: const Radius.circular(2.0),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        // ignore: deprecated_member_use
        year2023: false,
      ),
      sliderTheme: const SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
      ),
      brightness: brightness,
      appBarTheme: AppBarTheme(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: .0,
        backgroundColor: colorScheme.surface,
      ),
      fontFamily: fontFamily,
      typography: typography,
      textTheme: _applyFontVariations(textTheme),
    );
  }

  Future<void> findDynamicColor() async {
    try {
      final CorePalette? corePalette =
          await DynamicColorPlugin.getCorePalette();

      if (corePalette != null) {
        final seedColor = Color(corePalette.primary.get(40));

        lightDynamic = buildColorScheme(seedColor, Brightness.light, -1);
        darkDynamic = buildColorScheme(seedColor, Brightness.dark, -1);
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain core palette.');
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();

      if (accentColor != null) {
        lightDynamic = buildColorScheme(accentColor, Brightness.light, -1);
        darkDynamic = buildColorScheme(accentColor, Brightness.dark, -1);
        return;
      }
    } on PlatformException {
      logger.d('dynamic_color: Failed to obtain accent color.');
    }

    logger.d('dynamic_color: Dynamic color not detected on this device.');
  }

  (ThemeData, ThemeData) getThemeData() {
    final isDynamic = supportDynamic && PrefUtil.getValue<int>('color') == -1;
    if (isDynamic) {
      return (
        _lightTheme?.copyWith(
              colorScheme: lightDynamic,
              textTheme: buildTextTheme(lightDynamic!),
              typography: buildTypography(lightDynamic!),
            ) ??
            ThemeData.light(),
        _darkTheme?.copyWith(
              colorScheme: darkDynamic,
              textTheme: buildTextTheme(darkDynamic!),
              typography: buildTypography(darkDynamic!),
            ) ??
            ThemeData.dark(),
      );
    } else {
      return (_lightTheme ?? ThemeData.light(), _darkTheme ?? ThemeData.dark());
    }
  }

  /// 强制更新主题
  /// 一般在更改了主题色或者字体后调用
  static Future<void> forceUpdateTheme() async {
    await ThemeUtil().buildTheme();
    final themeData = ThemeUtil().getThemeData();
    Get.changeTheme(themeData.$1);
    Get.changeTheme(themeData.$2);
    await Get.forceAppUpdate();
  }

  static DefaultStyles getInstance(
    BuildContext context, {
    required ColorScheme customColorScheme,
  }) {
    final themeData = Theme.of(context);

    final baseStyle = context.theme.textTheme.bodyMedium!.copyWith(
      color: customColorScheme.onSurface,
    );
    const baseHorizontalSpacing = HorizontalSpacing(0, 0);
    const baseVerticalSpacing = VerticalSpacing(6, 0);
    final fontFamily = themeData.isCupertino ? 'Menlo' : 'Roboto Mono';

    final inlineCodeStyle = TextStyle(
      fontSize: 14,
      color: themeData.colorScheme.primary.withAlpha(200),
      fontFamily: fontFamily,
    );

    return DefaultStyles(
      h1: DefaultTextBlockStyle(
        context.theme.textTheme.titleLarge!.copyWith(
          color: customColorScheme.primary,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(16, 0),
        VerticalSpacing.zero,
        null,
      ),
      h2: DefaultTextBlockStyle(
        context.theme.textTheme.titleMedium!.copyWith(
          color: customColorScheme.secondary,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(8, 0),
        VerticalSpacing.zero,
        null,
      ),
      h3: DefaultTextBlockStyle(
        context.theme.textTheme.titleSmall!.copyWith(
          color: customColorScheme.onSurface,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(8, 0),
        VerticalSpacing.zero,
        null,
      ),
      h4: DefaultTextBlockStyle(
        context.theme.textTheme.titleSmall!.copyWith(
          color: customColorScheme.onSurface,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h5: DefaultTextBlockStyle(
        context.theme.textTheme.titleSmall!.copyWith(
          color: customColorScheme.onSurface,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h6: DefaultTextBlockStyle(
        context.theme.textTheme.titleSmall!.copyWith(
          color: customColorScheme.onSurface,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(4, 0),
        VerticalSpacing.zero,
        null,
      ),
      lineHeightNormal: DefaultTextBlockStyle(
        baseStyle.copyWith(height: 1.15),
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      lineHeightTight: DefaultTextBlockStyle(
        baseStyle.copyWith(height: 1.30),
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      lineHeightOneAndHalf: DefaultTextBlockStyle(
        baseStyle.copyWith(height: 1.55),
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      lineHeightDouble: DefaultTextBlockStyle(
        baseStyle.copyWith(height: 2),
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      paragraph: DefaultTextBlockStyle(
        baseStyle,
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      bold: const TextStyle(fontWeight: FontWeight.bold),
      subscript: const TextStyle(
        fontFeatures: [FontFeature.liningFigures(), FontFeature.subscripts()],
      ),
      superscript: const TextStyle(
        fontFeatures: [FontFeature.liningFigures(), FontFeature.superscripts()],
      ),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      small: const TextStyle(fontSize: 12),
      underline: const TextStyle(decoration: TextDecoration.underline),
      strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
      inlineCode: InlineCodeStyle(
        backgroundColor: Colors.grey.shade100,
        radius: const Radius.circular(3),
        style: inlineCodeStyle,
        header1: inlineCodeStyle.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w500,
        ),
        header2: inlineCodeStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        header3: inlineCodeStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      link: TextStyle(
        color: themeData.colorScheme.secondary,
        decoration: TextDecoration.underline,
      ),
      placeHolder: DefaultTextBlockStyle(
        baseStyle.copyWith(
          fontSize: 20,
          height: 1.5,
          color: Colors.grey.withValues(alpha: 0.6),
        ),
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      lists: DefaultListBlockStyle(
        baseStyle,
        baseHorizontalSpacing,
        baseVerticalSpacing,
        const VerticalSpacing(0, 6),
        null,
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(color: baseStyle.color!.withValues(alpha: 0.6)),
        baseHorizontalSpacing,
        baseVerticalSpacing,
        const VerticalSpacing(6, 2),
        BoxDecoration(
          border: Border(
            left: BorderSide(width: 4, color: Colors.grey.shade300),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        TextStyle(
          color: Colors.blue.shade900.withValues(alpha: 0.6),
          fontFamily: fontFamily,
          fontSize: 13,
          height: 1.15,
        ),
        baseHorizontalSpacing,
        baseVerticalSpacing,
        VerticalSpacing.zero,
        BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      indent: DefaultTextBlockStyle(
        baseStyle,
        baseHorizontalSpacing,
        baseVerticalSpacing,
        const VerticalSpacing(0, 6),
        null,
      ),
      align: DefaultTextBlockStyle(
        baseStyle,
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      leading: DefaultTextBlockStyle(
        baseStyle,
        baseHorizontalSpacing,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      sizeSmall: const TextStyle(fontSize: 10),
      sizeLarge: const TextStyle(fontSize: 18),
      sizeHuge: const TextStyle(fontSize: 22),
    );
  }
}
