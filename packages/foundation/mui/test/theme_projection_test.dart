import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

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
    testWidgets('$brightness 排版投影与 M3 2021 逐级等价', (tester) async {
      final mui = buildMuiTheme(brightness: brightness);
      final projected = mui;
      final m3 = _levels(
        Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: projected.colorScheme,
        ).englishLike,
      );

      final now = _levels(await _resolveInTree(tester, projected));

      for (final key in now.keys) {
        final a = now[key]!;
        final b = m3[key]!;
        expect(a.fontSize, b.fontSize, reason: '$key fontSize 偏离 M3');
        expect(a.height, b.height, reason: '$key height 偏离 M3');
        expect(
          a.letterSpacing,
          b.letterSpacing,
          reason: '$key letterSpacing 偏离 M3',
        );
        expect(a.fontWeight, b.fontWeight, reason: '$key fontWeight 偏离 M3');
        expect(a.fontVariations, [
          FontVariation('wght', b.fontWeight!.value.toDouble()),
        ], reason: '$key 的 wght 轴与 fontWeight 不一致');
        expect(a.inherit, isFalse, reason: '$key 必须整块替换');
        expect(
          a.color,
          projected.colorScheme.onSurface,
          reason: '$key 的投影色应为 onSurface',
        );
      }
    });

    testWidgets('$brightness 强调档：只加字重，几何一动不动', (tester) async {
      final mui = buildMuiTheme(brightness: brightness);
      for (final level in MuiTypography.levels) {
        final typography = MuiTheme.viewOf(mui).typography;
        final base = typography.byLevel(level).onSurface;
        final emphasized = typography.byLevel(level).emphasized.onSurface;
        expect(emphasized.fontSize, base.fontSize, reason: '$level 字号被改了');
        expect(emphasized.height, base.height, reason: '$level 行高被改了');
        expect(
          emphasized.letterSpacing,
          base.letterSpacing,
          reason: '$level 字距被改了',
        );
        final expected = base.fontSize! >= 22
            ? FontWeight.w700
            : FontWeight.w600;
        expect(emphasized.fontWeight, expected, reason: '$level 强调档字重不对');
        expect(emphasized.fontVariations, [
          FontVariation('wght', expected.value.toDouble()),
        ], reason: '$level 强调档的 wght 轴没跟上');
      }
    });
  }

  testWidgets(
    'MaterialApp 根下的 DefaultTextStyle 是 48px 红字 —— MuiScaffold 必须自己发',
    (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: Brightness.light),
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
    final mui = buildMuiTheme(brightness: Brightness.light);
    late TextStyle style;
    late TextStyle emphasized;
    await tester.pumpWidget(
      MaterialApp(
        theme: mui,
        home: Builder(
          builder: (context) {
            style = context.theme.typography.titleLarge.onSurfaceVariant;
            emphasized = context.theme.typography.bodyMedium.emphasized.primary;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(style.color, mui.colorScheme.onSurfaceVariant);
    expect(style.fontSize, 22);
    expect(style.fontWeight, FontWeight.w400);

    expect(emphasized.color, mui.colorScheme.primary);
    expect(emphasized.fontSize, 14);
    expect(emphasized.fontWeight, FontWeight.w600);
    expect(emphasized.fontVariations, [const FontVariation('wght', 600)]);
  });

  testWidgets('context.theme 直接派生自 MaterialApp 的 theme，无需额外注入', (tester) async {
    final mui = buildMuiTheme(brightness: Brightness.light);
    late MuiThemeData seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: mui,
        home: Builder(
          builder: (context) {
            seen = MuiTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.colors, mui.colorScheme);
    expect(seen.tokens, mui.extension<MuiTokens>());
    expect(
      seen.colors.surface,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF000000),
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).surface,
    );
  });
}
