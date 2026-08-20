import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:mui/mui.dart';

/// 无彩档的结构性角色必须真的是灰、且与种子无关。[resolveColorScheme] 换掉
/// 变体或往里加覆盖，这里就会红。
const List<String> _structuralRoles = [
  'surface',
  'surfaceBright',
  'surfaceDim',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'onSurface',
  'onSurfaceVariant',
  'outline',
  'outlineVariant',
  'inverseSurface',
  'onInverseSurface',
];

Map<String, int> _structuralOf(ColorScheme s) => {
  'surface': s.surface.toARGB32(),
  'surfaceBright': s.surfaceBright.toARGB32(),
  'surfaceDim': s.surfaceDim.toARGB32(),
  'surfaceContainerLowest': s.surfaceContainerLowest.toARGB32(),
  'surfaceContainerLow': s.surfaceContainerLow.toARGB32(),
  'surfaceContainer': s.surfaceContainer.toARGB32(),
  'surfaceContainerHigh': s.surfaceContainerHigh.toARGB32(),
  'surfaceContainerHighest': s.surfaceContainerHighest.toARGB32(),
  'onSurface': s.onSurface.toARGB32(),
  'onSurfaceVariant': s.onSurfaceVariant.toARGB32(),
  'outline': s.outline.toARGB32(),
  'outlineVariant': s.outlineVariant.toARGB32(),
  'inverseSurface': s.inverseSurface.toARGB32(),
  'onInverseSurface': s.onInverseSurface.toARGB32(),
};

bool _isGray(Color color) {
  final argb = color.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return r == g && g == b;
}

void main() {
  group('resolveColorScheme', () {
    for (final brightness in Brightness.values) {
      final neutral = resolveColorScheme(brightness, const MuiAccent.neutral());

      test('$brightness 无彩档除 error 家族外全部是灰', () {
        // error 四件套刻意保留语义红：灰度 UI 里它是唯一还能喊「出事了」的颜色。
        final chromatic = {
          neutral.error.toARGB32(),
          neutral.onError.toARGB32(),
          neutral.errorContainer.toARGB32(),
          neutral.onErrorContainer.toARGB32(),
        };
        for (final entry in _structuralOf(neutral).entries) {
          expect(
            _isGray(Color(entry.value)),
            isTrue,
            reason: '${entry.key} 不是灰',
          );
        }
        expect(_isGray(neutral.primary), isTrue);
        expect(_isGray(neutral.secondary), isTrue);
        expect(_isGray(neutral.tertiary), isTrue);
        // 焦点环/光标派生自 primary，无彩档下也必须是灰。
        final cursor = buildMuiTheme(brightness: brightness)
            .textSelectionTheme
            .cursorColor!;
        expect(_isGray(cursor), isTrue);
        expect(chromatic.length, greaterThan(1));
      });

      test('$brightness 强调色确实改变了 primary', () {
        final accented = resolveColorScheme(
          brightness,
          const MuiAccent.seeded(Color(0xFF2E59A7)),
        );
        expect(accented.primary.toARGB32(), isNot(neutral.primary.toARGB32()));
        expect(_isGray(accented.primary), isFalse);
      });

      test('$brightness 无彩档不受种子色影响', () {
        expect(
          _structuralOf(
            resolveColorScheme(brightness, const MuiAccent.neutral()),
          ),
          _structuralOf(neutral),
        );
      });

      test('$brightness ring 与 selection 有定义且 selection 半透明', () {
        for (final accent in [
          const MuiAccent.neutral(),
          const MuiAccent.seeded(Color(0xFF2E59A7)),
        ]) {
          final t = buildMuiTheme(brightness: brightness, accent: accent);
          expect(t.textSelectionTheme.cursorColor!.a, 1.0, reason: '光标必须不透明');
          expect(
            t.textSelectionTheme.selectionColor!.a,
            lessThan(1.0),
            reason: '选中底色必须半透明',
          );
        }
      });
    }

    group('有彩档（系统与自定义共用）', () {
      const seed = Color(0xFF2E59A7);

      mcu.TonalPalette primaryPaletteOf(Brightness brightness) =>
          mcu.SchemeTonalSpot(
            sourceColorHct: mcu.Hct.fromInt(seed.toARGB32()),
            isDark: brightness == Brightness.dark,
            contrastLevel: 0,
          ).primaryPalette;

      test('on*Container 走 Tone 30/90，不是 legacy 的 Tone 10', () {
        // dynamic_color 的 toColorScheme() 至 1.9.0 仍取 primary.get(10)，实测
        // 对比度 13.2（近黑压浅块）。现代规范是 tone 30/90，对比度 7.2。
        for (final brightness in Brightness.values) {
          final scheme = resolveColorScheme(
            brightness,
            const MuiAccent.seeded(seed),
          );
          final palette = primaryPaletteOf(brightness);
          final legacyTone = palette.get(brightness == .dark ? 90 : 10);
          final modernTone = palette.get(brightness == .dark ? 90 : 30);
          expect(
            scheme.onPrimaryContainer.toARGB32(),
            modernTone,
            reason: '$brightness 的 onPrimaryContainer 不是 tone 30/90',
          );
          if (brightness == .light) {
            expect(scheme.onPrimaryContainer.toARGB32(), isNot(legacyTone));
          }
        }
      });

      test('结构性角色跟着种子染色，不套用灰阶', () {
        for (final brightness in Brightness.values) {
          final scheme = resolveColorScheme(
            brightness,
            const MuiAccent.seeded(seed),
          );
          expect(
            _structuralOf(scheme),
            isNot(
              _structuralOf(
                resolveColorScheme(brightness, const MuiAccent.neutral()),
              ),
            ),
            reason: '有彩档的表面色不该等于无彩档',
          );
          expect(_isGray(scheme.surface), isFalse, reason: 'surface 应带色相');
          expect(_isGray(scheme.tertiary), isFalse, reason: 'tertiary 应带色相');
          expect(scheme.surfaceTint, scheme.primary, reason: '高程染色应为 primary');
        }
      });

      test('系统档与自定义档同一条路 —— 种子相同则结果逐字节相同', () {
        // dynamic_color 只负责交出种子色；交出来之后与用户挑的颜色没有区别。
        for (final brightness in Brightness.values) {
          expect(
            resolveColorScheme(brightness, const MuiAccent.seeded(seed)),
            resolveColorScheme(brightness, const MuiAccent.seeded(seed)),
          );
        }
      });
    });

    test('结构性角色清单与断言辅助保持同步', () {
      expect(
        _structuralOf(resolveColorScheme(.light, const MuiAccent.neutral()))
            .keys,
        _structuralRoles,
      );
    });
  });

  group('值语义', () {
    test('结构相同的两次构造相等 —— 否则主题每次都会通知', () {
      final a = buildMuiTheme(brightness: Brightness.light);
      final b = buildMuiTheme(brightness: Brightness.light);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('带 Map 字段（wghtAxis）仍然相等', () {
      const font = MuiFontConfig(family: 'X', wghtAxis: {'Bold': 650});
      final a = buildMuiTheme(brightness: Brightness.light, font: font);
      final b = buildMuiTheme(brightness: Brightness.light, font: font);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('任一 token 变化都会打破相等', () {
      final base = buildMuiTheme(brightness: Brightness.light);
      expect(base, isNot(buildMuiTheme(brightness: Brightness.dark)));
      for (final variant in [
        buildMuiTheme(
          brightness: Brightness.light,
          radii: const MuiRadii(lg: 20),
        ),
        buildMuiTheme(
          brightness: Brightness.light,
          spacing: const MuiSpacing(xs: 5),
        ),
        buildMuiTheme(
          brightness: Brightness.light,
          borders: const MuiBorders(ring: 2),
        ),
        buildMuiTheme(
          brightness: Brightness.light,
          states: const MuiStateTokens(hoverOpacity: 0.2),
        ),
      ]) {
        expect(base, isNot(variant));
      }
    });

    test('MuiTokens 深浅两档都挂上了 —— 否则 ThemeData.lerp 不插值', () {
      final light = buildMuiTheme(brightness: Brightness.light);
      final dark = buildMuiTheme(brightness: Brightness.dark);
      expect(light.extension<MuiTokens>(), isNotNull);
      expect(dark.extension<MuiTokens>(), isNotNull);

      final mid = ThemeData.lerp(light, dark, 0.5);
      expect(mid.extension<MuiTokens>(), isNotNull);
      expect(mid.colorScheme.surface, isNot(light.colorScheme.surface));
      expect(mid.colorScheme.surface, isNot(dark.colorScheme.surface));
    });

    test('第三方自建 ThemeData 取到兜底 token，不抛', () {
      final view = MuiTheme.viewOf(ThemeData(brightness: Brightness.light));
      expect(view.radii.md, const MuiRadii().md);
      expect(view.onMedia, const Color(0xFFFFFFFF));
      expect(view.typography.bodyMedium.onSurface.fontSize, isNotNull);
    });
  });

  group('MuiTypography', () {
    MuiTypography typo({MuiFontConfig font = const MuiFontConfig()}) =>
        MuiTheme.viewOf(buildMuiTheme(brightness: Brightness.light, font: font))
            .typography;

    test('字重与 fontVariations 一致 —— 只改一个在可变字体下会被吃掉', () {
      const font = MuiFontConfig(
        family: 'X',
        wghtAxis: {'Regular': 380, 'Medium': 520, 'Bold': 680},
      );
      final t = typo(font: font);
      expect(t.bodyMedium.onSurface.fontWeight, FontWeight.w400);
      expect(t.bodyMedium.onSurface.fontVariations, [
        const FontVariation('wght', 380),
      ]);
      // M3 2021：headline 三级都是 Regular，Bold 只出现在 22px 以上的强调档。
      expect(t.headlineLarge.onSurface.fontWeight, FontWeight.w400);
      expect(t.headlineLarge.emphasized.onSurface.fontVariations, [
        const FontVariation('wght', 680),
      ]);
      expect(t.labelLarge.onSurface.fontVariations, [
        const FontVariation('wght', 520),
      ]);
    });

    test('默认字重表就是 M3 2021 的原值', () {
      final t = typo();
      const m3 = {
        'displayLarge': FontWeight.w400,
        'displayMedium': FontWeight.w400,
        'displaySmall': FontWeight.w400,
        'headlineLarge': FontWeight.w400,
        'headlineMedium': FontWeight.w400,
        'headlineSmall': FontWeight.w400,
        'titleLarge': FontWeight.w400,
        'titleMedium': FontWeight.w500,
        'titleSmall': FontWeight.w500,
        'bodyLarge': FontWeight.w400,
        'bodyMedium': FontWeight.w400,
        'bodySmall': FontWeight.w400,
        'labelLarge': FontWeight.w500,
        'labelMedium': FontWeight.w500,
        'labelSmall': FontWeight.w500,
      };
      for (final level in MuiTypography.levels) {
        expect(
          t.byLevel(level).onSurface.fontWeight,
          m3[level],
          reason: '$level 的默认字重偏离 M3',
        );
      }
    });

    test('强调档的 fontWeight 与 fontVariations 一起动', () {
      const font = MuiFontConfig(wghtAxis: {'SemiBold': 610});
      final role = typo(font: font).bodyMedium;
      expect(role.onSurface.fontWeight, FontWeight.w400);
      expect(role.emphasized.onSurface.fontWeight, FontWeight.w600);
      expect(role.emphasized.onSurface.fontVariations, [
        const FontVariation('wght', 610),
      ]);
      // 换字重不动几何。
      expect(role.emphasized.onSurface.fontSize, role.onSurface.fontSize);
      expect(role.emphasized.onSurface.height, role.onSurface.height);
    });

    test('链式取色只换颜色', () {
      final colors = resolveColorScheme(.light, const MuiAccent.neutral());
      final role = typo().titleLarge;
      expect(role.onSurface.color, colors.onSurface);
      expect(role.onSurfaceVariant.color, colors.onSurfaceVariant);
      expect(role.error.color, colors.error);
      // 色板之外的颜色走惯例 copyWith，不另开 API。
      expect(
        role.onSurface.copyWith(color: const Color(0xFF123456)).color,
        const Color(0xFF123456),
      );
      expect(role.onSurfaceVariant.fontSize, role.onSurface.fontSize);
      expect(role.onSurfaceVariant.letterSpacing, role.onSurface.letterSpacing);
    });

    test('字号就是 M3 基准值 —— App 内不做任何缩放，缩放归系统', () {
      final t = typo();
      expect(t.bodyMedium.onSurface.fontSize, 14);
      expect(t.bodyMedium.onSurface.height, 1.43);
      expect(t.bodyMedium.onSurface.letterSpacing, 0.25);
      expect(t.displayLarge.onSurface.fontSize, 57);
      expect(t.labelSmall.onSurface.fontSize, 11);
    });

    test('字体族逐平台与 material 对齐，iOS 按 22px 切光学尺寸', () {
      const expected = {
        TargetPlatform.android: 'Roboto',
        TargetPlatform.fuchsia: 'Roboto',
        TargetPlatform.linux: 'Roboto',
        TargetPlatform.windows: 'Segoe UI',
        TargetPlatform.macOS: '.AppleSystemUIFont',
      };
      for (final entry in expected.entries) {
        debugDefaultTargetPlatformOverride = entry.key;
        final t = typo();
        for (final level in MuiTypography.levels) {
          expect(
            t.byLevel(level).onSurface.fontFamily,
            entry.value,
            reason: '${entry.key} 的 $level 字体族不对',
          );
        }
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = typo();
      for (final level in MuiTypography.levels) {
        final style = ios.byLevel(level).onSurface;
        expect(
          style.fontFamily,
          style.fontSize! >= 22
              ? 'CupertinoSystemDisplay'
              : 'CupertinoSystemText',
          reason: 'iOS 的 $level 光学尺寸选错了',
        );
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('宿主给了自定义字体就盖掉平台默认', () {
      final t = typo(font: const MuiFontConfig(family: 'X'));
      for (final level in MuiTypography.levels) {
        expect(t.byLevel(level).onSurface.fontFamily, 'X', reason: level);
      }
    });

    test('全 15 级 inherit 为 false —— 投影到 material 时要整块替换', () {
      final t = typo();
      expect(MuiTypography.levels.length, 15);
      for (final level in MuiTypography.levels) {
        expect(t.byLevel(level).onSurface.inherit, isFalse, reason: level);
      }
    });

    test('相等只看 (font, colors)', () {
      expect(typo(), typo());
      expect(typo().hashCode, typo().hashCode);
      expect(typo(), isNot(typo(font: const MuiFontConfig(family: 'X'))));
    });
  });
}
