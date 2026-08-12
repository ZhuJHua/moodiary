import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:mui/mui.dart';

/// 复现**改造前** ThemeManager 的排版表达式：`Typography.material2021` 的
/// black/white + 逐级 fontWeight/fontVariations 覆盖。
/// 新路径改成由 [MuiTextTheme] 整块投影，这个函数是它的对照组。
TextTheme legacyTextTheme(ColorScheme cs) {
  final typography = Typography.material2021(
    platform: TargetPlatform.android,
    colorScheme: cs,
  );
  final base = cs.brightness == Brightness.light
      ? typography.black
      : typography.white;
  TextStyle? st(TextStyle? s, FontWeight fw, double axis) => s?.copyWith(
    fontWeight: fw,
    fontVariations: [FontVariation('wght', axis)],
  );
  return base.copyWith(
    displayLarge: st(base.displayLarge, FontWeight.w500, 500),
    displayMedium: st(base.displayMedium, FontWeight.w500, 500),
    displaySmall: st(base.displaySmall, FontWeight.w500, 500),
    headlineLarge: st(base.headlineLarge, FontWeight.w700, 700),
    headlineMedium: st(base.headlineMedium, FontWeight.w600, 600),
    headlineSmall: st(base.headlineSmall, FontWeight.w500, 500),
    titleLarge: st(base.titleLarge, FontWeight.w600, 600),
    titleMedium: st(base.titleMedium, FontWeight.w500, 500),
    titleSmall: st(base.titleSmall, FontWeight.w500, 500),
    bodyLarge: st(base.bodyLarge, FontWeight.w400, 400),
    bodyMedium: st(base.bodyMedium, FontWeight.w400, 400),
    bodySmall: st(base.bodySmall, FontWeight.w400, 400),
    labelLarge: st(base.labelLarge, FontWeight.w500, 500),
    labelMedium: st(base.labelMedium, FontWeight.w500, 500),
    labelSmall: st(base.labelSmall, FontWeight.w400, 400),
  );
}

Map<String, TextStyle?> _levels(TextTheme t) => {
  'displayLarge': t.displayLarge,
  'displayMedium': t.displayMedium,
  'displaySmall': t.displaySmall,
  'headlineLarge': t.headlineLarge,
  'headlineMedium': t.headlineMedium,
  'headlineSmall': t.headlineSmall,
  'titleLarge': t.titleLarge,
  'titleMedium': t.titleMedium,
  'titleSmall': t.titleSmall,
  'bodyLarge': t.bodyLarge,
  'bodyMedium': t.bodyMedium,
  'bodySmall': t.bodySmall,
  'labelLarge': t.labelLarge,
  'labelMedium': t.labelMedium,
  'labelSmall': t.labelSmall,
};

Future<TextTheme> _resolveInTree(WidgetTester tester, ThemeData theme) async {
  late TextTheme resolved;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          resolved = Theme.of(context).textTheme;
          return const SizedBox();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness 排版投影与改造前逐级等价', (tester) async {
      // 在真实渲染树里比，而不是比构造出的对象 —— 差异藏在 ThemeData 的
      // `typography.black.merge(textTheme)` 与 `ThemeData.localize` 两层里。
      final mui = MuiThemeData(brightness: brightness);
      final projected = materialThemeFrom(mui);
      final legacy = ThemeData(
        colorScheme: projected.colorScheme,
        brightness: brightness,
        typography: Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: projected.colorScheme,
        ),
        textTheme: legacyTextTheme(projected.colorScheme),
      );

      final now = _levels(await _resolveInTree(tester, projected));
      final before = _levels(await _resolveInTree(tester, legacy));

      for (final key in now.keys) {
        final a = now[key]!;
        final b = before[key]!;
        expect(a.fontSize, b.fontSize, reason: '$key fontSize 漂了');
        expect(a.height, b.height, reason: '$key height 漂了');
        expect(
          a.letterSpacing,
          b.letterSpacing,
          reason: '$key letterSpacing 漂了',
        );
        expect(a.fontWeight, b.fontWeight, reason: '$key fontWeight 漂了');
        expect(a.fontVariations, b.fontVariations, reason: '$key wght 轴漂了');
        expect(a.color, b.color, reason: '$key color 漂了');
        expect(a.inherit, b.inherit, reason: '$key inherit 漂了');
      }
    });
  }

  testWidgets(
    'MaterialApp 根下的 DefaultTextStyle 是 48px 红字 —— MuiScaffold 必须自己发',
    (tester) async {
      // 这不是 bug，是 MaterialApp 故意传给 WidgetsApp.textStyle 的 `_errorTextStyle`
      // （material/app.dart:45，debugLabel 写着「考虑把文字放进 Material」）。
      // 真正能用的兜底来自 Scaffold → Material → AnimatedDefaultTextStyle。
      //
      // 所以批次 3 的 MuiScaffold 一旦替掉 Scaffold 而**不自己发 DefaultTextStyle**，
      // 整页文字会变成 48px 红字黄双下划线。这条断言把这个前提钉在这里，
      // 等 MuiScaffold 落地时把它翻过来断言「不是 48」。
      late TextStyle style;
      await tester.pumpWidget(
        MaterialApp(
          theme: materialThemeFrom(MuiThemeData(brightness: .light)),
          home: Builder(
            builder: (context) {
              style = DefaultTextStyle.of(context).style;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(style.fontSize, 48.0);
      expect(style.fontFamily, 'monospace');
    },
  );

  testWidgets('链式用法：context.theme.typography.titleLarge.onSurfaceVariant', (
    tester,
  ) async {
    final mui = MuiThemeData(brightness: .light);
    late TextStyle style;
    late TextStyle emphasized;
    await tester.pumpWidget(
      MaterialApp(
        theme: materialThemeFrom(mui),
        builder: (context, child) => MuiAnimatedTheme(data: mui, child: child!),
        home: Builder(
          builder: (context) {
            style = context.theme.typography.titleLarge.onSurfaceVariant;
            emphasized = context.theme.typography.bodyMedium.bold.primary;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(style.color, mui.colors.onSurfaceVariant);
    expect(style.fontSize, 22);
    expect(style.fontWeight, FontWeight.w600);

    expect(emphasized.color, mui.colors.primary);
    expect(emphasized.fontSize, 14);
    // 字重两条路必须一起动，否则可变字体下 fontWeight 会被 fontVariations 吃掉。
    expect(emphasized.fontWeight, FontWeight.w700);
    expect(emphasized.fontVariations, [const FontVariation('wght', 700)]);
  });

  testWidgets('MuiTheme 能穿过 MaterialApp.builder 传到路由子树', (tester) async {
    final mui = MuiThemeData(brightness: .light);
    late MuiThemeData seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: materialThemeFrom(mui),
        builder: (context, child) => MuiAnimatedTheme(data: mui, child: child!),
        home: Builder(
          builder: (context) {
            seen = MuiTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, mui);
    // 无彩档就是标准 SchemeMonochrome，不写死色值。
    expect(
      seen.colors.surface,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF000000),
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).surface,
    );
  });
}
