import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/internal.dart';
import 'package:mood_diary/common/values/colors.dart';

import '../src/rust/api/font.dart';
import 'data/pref.dart';

class ThemeUtil {
  static Future<bool> supportDynamicColor() async {
    return (await DynamicColorPlugin.getCorePalette()) != null;
  }

  static Future<Color> getDynamicColor() async {
    return Color((await DynamicColorPlugin.getCorePalette())!.primary.get(40));
  }

  static Future<ThemeData> buildTheme(Brightness brightness) async {
    final color = PrefUtil.getValue<int>('color')!;
    var seedColor = (color == -1)
        ? Color(PrefUtil.getValue<int>('systemColor')!)
        : AppColor.themeColorList[
            (color >= 0 && color < AppColor.themeColorList.length) ? color : 0];

    final customFont = PrefUtil.getValue<String>('customFont')!;
    String? fontFamily;

    // 加载自定义字体
    if (customFont.isNotEmpty) {
      fontFamily = await FontReader.getFontNameFromTtf(ttfFilePath: customFont);
      if (fontFamily != null) {
        await DynamicFont.file(fontFamily: fontFamily, filepath: customFont)
            .load();
      }
    }
    // 字体变体应用到 TextTheme 的函数
    TextTheme applyFontVariations(TextTheme baseTheme, String? fontFamily) {
      const fontVariation = FontVariation('wght', 400);
      return baseTheme.copyWith(
        displayLarge: baseTheme.displayLarge
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        displayMedium: baseTheme.displayMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        displaySmall: baseTheme.displaySmall
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        headlineLarge: baseTheme.headlineLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 500)]),
        headlineMedium: baseTheme.headlineMedium?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 500)]),
        headlineSmall: baseTheme.headlineSmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 500)]),
        titleLarge: baseTheme.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 600)]),
        titleMedium: baseTheme.titleMedium?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 500)]),
        titleSmall: baseTheme.titleSmall
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodyLarge: baseTheme.bodyLarge
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodyMedium: baseTheme.bodyMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodySmall: baseTheme.bodySmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 300)]),
        labelLarge: baseTheme.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 500)]),
        labelMedium: baseTheme.labelMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        labelSmall: baseTheme.labelSmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 300)]),
      );
    }

    TextTheme applyMiSansFontVariations(
        TextTheme baseTheme, String? fontFamily) {
      const fontVariation = FontVariation('wght', 330);
      return baseTheme.copyWith(
        displayLarge: baseTheme.displayLarge
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        displayMedium: baseTheme.displayMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        displaySmall: baseTheme.displaySmall
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        headlineLarge: baseTheme.headlineLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 380)]),
        headlineMedium: baseTheme.headlineMedium?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 380)]),
        headlineSmall: baseTheme.headlineSmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 380)]),
        titleLarge: baseTheme.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 520)]),
        titleMedium: baseTheme.titleMedium?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 520)]),
        titleSmall: baseTheme.titleSmall
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodyLarge: baseTheme.bodyLarge
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodyMedium: baseTheme.bodyMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        bodySmall: baseTheme.bodySmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 250)]),
        labelLarge: baseTheme.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 380)]),
        labelMedium: baseTheme.labelMedium
            ?.copyWith(fontFamily: fontFamily, fontVariations: [fontVariation]),
        labelSmall: baseTheme.labelSmall?.copyWith(
            fontFamily: fontFamily,
            fontVariations: [const FontVariation('wght', 250)]),
      );
    }

    // 基础主题
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        dynamicSchemeVariant: color == 0
            ? DynamicSchemeVariant.monochrome
            : DynamicSchemeVariant.tonalSpot,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: brightness,
      textTheme: fontFamily != 'MiSans VF'
          ? applyFontVariations(
              brightness == Brightness.light
                  ? Typography.material2021().black
                  : Typography.material2021().white,
              fontFamily,
            )
          : applyMiSansFontVariations(
              brightness == Brightness.light
                  ? Typography.material2021().black
                  : Typography.material2021().white,
              fontFamily,
            ),
    );
  }

  static DefaultStyles getInstance(BuildContext context) {
    final themeData = Theme.of(context);
    final textStyle = Theme.of(context).textTheme;
    final baseStyle = textStyle.bodyMedium!.copyWith(
      fontSize: 16,
      height: 1.5,
      decoration: TextDecoration.none,
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
          textStyle.titleLarge!.copyWith(
            fontSize: 34,
            color: textStyle.titleLarge!.color,
            letterSpacing: -0.5,
            height: 1.083,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
          baseHorizontalSpacing,
          const VerticalSpacing(16, 0),
          VerticalSpacing.zero,
          null),
      h2: DefaultTextBlockStyle(
          textStyle.titleMedium!.copyWith(
            fontSize: 30,
            color: textStyle.titleMedium!.color,
            letterSpacing: -0.8,
            height: 1.067,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
          baseHorizontalSpacing,
          const VerticalSpacing(8, 0),
          VerticalSpacing.zero,
          null),
      h3: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(
          fontSize: 24,
          color: textStyle.titleSmall!.color,
          letterSpacing: -0.5,
          height: 1.083,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(8, 0),
        VerticalSpacing.zero,
        null,
      ),
      h4: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(
          fontSize: 20,
          color: textStyle.titleSmall!.color,
          letterSpacing: -0.4,
          height: 1.1,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h5: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(
          fontSize: 18,
          color: textStyle.titleSmall!.color,
          letterSpacing: -0.2,
          height: 1.11,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
        baseHorizontalSpacing,
        const VerticalSpacing(6, 0),
        VerticalSpacing.zero,
        null,
      ),
      h6: DefaultTextBlockStyle(
        textStyle.titleSmall!.copyWith(
          fontSize: 16,
          color: textStyle.titleSmall!.color,
          letterSpacing: -0.1,
          height: 1.125,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
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
