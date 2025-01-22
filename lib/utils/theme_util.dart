import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/internal.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/src/rust/api/font.dart';

final Set<String> loadedFonts = {};

class ThemeUtil {
  static Future<bool> supportDynamicColor() async {
    return (await DynamicColorPlugin.getCorePalette()) != null;
  }

  static Future<Color> getDynamicColor() async {
    return Color((await DynamicColorPlugin.getCorePalette())!.primary.get(40));
  }

  static Map<String, double> _unifyFontWeights(
      Map<String, double> fontWeights) {
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

    Map<String, double> unified = {};

    for (var entry in fontWeights.entries) {
      String originalName = entry.key;
      double weight = entry.value;
      String unifiedName = nameMapping[originalName] ?? originalName;

      if (unified.containsKey(unifiedName)) {
        double existingWeight = unified[unifiedName]!;
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

  static TextTheme _applyFontVariations(TextTheme baseTheme, String? fontFamily,
      {required Map<String, double> wghtAxisMap}) {
    var regularFontWeight = wghtAxisMap['Regular'] ?? 400;
    var mediumFontWeight = wghtAxisMap['Medium'] ?? 500;
    var semiBoldFontWeight = wghtAxisMap['SemiBold'] ?? 600;
    var boldFontWeight = wghtAxisMap['Bold'] ?? 700;
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

  static Future<ThemeData> buildTheme(Brightness brightness) async {
    final color = PrefUtil.getValue<int>('color')!;
    var seedColor = (color == -1)
        ? Color(PrefUtil.getValue<int>('systemColor')!)
        : AppColor.themeColorList[
            (color >= 0 && color < AppColor.themeColorList.length) ? color : 0];

    final customFont = PrefUtil.getValue<String>('customFont')!;
    String? fontFamily;
    Map<String, double> wghtAxisMap = {};

    // 加载自定义字体
    if (customFont.isNotEmpty) {
      fontFamily = await FontReader.getFontNameFromTtf(ttfFilePath: customFont);
      if (fontFamily != null) {
        if (!loadedFonts.contains(fontFamily)) {
          var res = await DynamicFont.file(
                  fontFamily: fontFamily, filepath: customFont)
              .load();
          if (res) loadedFonts.add(fontFamily);
        }
        wghtAxisMap = _unifyFontWeights(
            await FontReader.getWghtAxisFromVfFont(ttfFilePath: customFont));
      }
    }

    // colorScheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: color == 0
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
    );
    // typography
    final typography = Typography.material2021(
        platform: defaultTargetPlatform, colorScheme: colorScheme);
    final defaultTextTheme =
        brightness == Brightness.light ? typography.black : typography.white;

    return ThemeData(
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(colorScheme.primaryContainer),
        thickness: WidgetStateProperty.all(4.0),
        radius: const Radius.circular(2.0),
      ),
      brightness: brightness,
      fontFamily: fontFamily,
      textTheme: _applyFontVariations(
        defaultTextTheme,
        fontFamily,
        wghtAxisMap: wghtAxisMap,
      ),
    );
  }

  static DefaultStyles getInstance(BuildContext context,
      {required ColorScheme customColorScheme}) {
    final themeData = Theme.of(context);
    final textStyle = Theme.of(context).textTheme;
    final baseStyle = textStyle.bodyMedium!.copyWith(
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
          textStyle.titleLarge!.copyWith(color: customColorScheme.primary),
          baseHorizontalSpacing,
          const VerticalSpacing(16, 0),
          VerticalSpacing.zero,
          null),
      h2: DefaultTextBlockStyle(
          textStyle.titleMedium!.copyWith(color: customColorScheme.secondary),
          baseHorizontalSpacing,
          const VerticalSpacing(8, 0),
          VerticalSpacing.zero,
          null),
      h3: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(color: customColorScheme.onSurface),
        baseHorizontalSpacing,
        const VerticalSpacing(8, 0),
        VerticalSpacing.zero,
        null,
      ),
      h4: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(color: customColorScheme.onSurface),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h5: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(color: customColorScheme.onSurface),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h6: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(color: customColorScheme.onSurface),
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
        fontFeatures: [
          FontFeature.liningFigures(),
          FontFeature.subscripts(),
        ],
      ),
      superscript: const TextStyle(
        fontFeatures: [
          FontFeature.liningFigures(),
          FontFeature.superscripts(),
        ],
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
          null),
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
          )),
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
