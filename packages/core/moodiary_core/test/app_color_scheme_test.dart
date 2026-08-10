import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:moodiary_core/moodiary_core.dart';

/// 中性板在无彩档与强调档之间必须逐字节相同 —— 「一套视觉语言」靠这条断言维持，
/// 而不是靠纪律。改 [NeutralRamp] 会连带改这里，那是预期；改 [AppColorScheme.resolve]
/// 的覆盖清单把某个结构性角色漏掉，这里就会红。
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

Map<String, int> _structuralOf(ColorScheme scheme) => {
  'surface': scheme.surface.toARGB32(),
  'surfaceBright': scheme.surfaceBright.toARGB32(),
  'surfaceDim': scheme.surfaceDim.toARGB32(),
  'surfaceContainerLowest': scheme.surfaceContainerLowest.toARGB32(),
  'surfaceContainerLow': scheme.surfaceContainerLow.toARGB32(),
  'surfaceContainer': scheme.surfaceContainer.toARGB32(),
  'surfaceContainerHigh': scheme.surfaceContainerHigh.toARGB32(),
  'surfaceContainerHighest': scheme.surfaceContainerHighest.toARGB32(),
  'onSurface': scheme.onSurface.toARGB32(),
  'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
  'outline': scheme.outline.toARGB32(),
  'outlineVariant': scheme.outlineVariant.toARGB32(),
  'inverseSurface': scheme.inverseSurface.toARGB32(),
  'onInverseSurface': scheme.onInverseSurface.toARGB32(),
};

bool _isGray(Color color) {
  final argb = color.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return r == g && g == b;
}

void main() {
  group('AppColorScheme.resolve', () {
    for (final brightness in Brightness.values) {
      final neutral = AppColorScheme.resolve(
        brightness,
        const AccentPalette.neutral(),
      );

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
        expect(chromatic.length, greaterThan(1));
      });

      test('$brightness 自定义档就是裸的 fromSeed，无任何覆盖', () {
        for (final seed in const [
          Color(0xFF2E59A7),
          Color(0xFFECD452),
          Color(0xFFA72126),
        ]) {
          expect(
            AppColorScheme.resolve(brightness, AccentPalette.seeded(seed)),
            ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
            reason: '种子 $seed 的自定义档被改过',
          );
        }
      });

      test('$brightness 强调色确实改变了 primary', () {
        final accented = AppColorScheme.resolve(
          brightness,
          const AccentPalette.seeded(Color(0xFF2E59A7)),
        );
        expect(accented.primary.toARGB32(), isNot(neutral.primary.toARGB32()));
        expect(_isGray(accented.primary), isFalse);
      });

      test('$brightness 无彩档不受种子色影响', () {
        // SchemeMonochrome 把 chroma 钉为 0，HctSolver 随即短路并丢弃色相。
        expect(
          _structuralOf(
            AppColorScheme.resolve(brightness, const AccentPalette.neutral()),
          ),
          _structuralOf(neutral),
        );
      });
    }

    group('系统档', () {
      // 模拟 OS 交上来的色板：真机上这五条盘由 dynamic_color 从壁纸取得，
      // 这里按同样的 hue/chroma 关系直接造，避开已废弃的 CorePalette。
      SystemPalettes palettesOf(int wallpaper) {
        final hct = mcu.Hct.fromInt(wallpaper);
        return SystemPalettes(
          primary: mcu.TonalPalette.of(hct.hue, hct.chroma),
          secondary: mcu.TonalPalette.of(hct.hue, hct.chroma / 3),
          tertiary: mcu.TonalPalette.of(hct.hue + 60, hct.chroma / 2),
          neutral: mcu.TonalPalette.of(hct.hue, 4),
          neutralVariant: mcu.TonalPalette.of(hct.hue, 8),
        );
      }

      test('primary 保住壁纸原色，不走「取种子重推」', () {
        // 重推会按 tone-40 色重算 chroma，把壁纸的饱和度丢掉。红色壁纸实测能漂到
        // ΔE 34（#B4271F 变 #904A42），这条断言就是拦它的。
        for (final wallpaper in const [0xFF2E59A7, 0xFFB3261E, 0xFF6750A4]) {
          final palettes = palettesOf(wallpaper);
          final scheme = AppColorScheme.resolve(
            .light,
            AccentPalette.system(palettes),
          );
          expect(
            scheme.primary.toARGB32(),
            palettes.primary.get(40),
            reason: '壁纸 ${wallpaper.toRadixString(16)} 的 primary 被重推了',
          );
        }
      });

      test('on*Container 走 Tone 30/90，不是 legacy 的 Tone 10', () {
        // dynamic_color 的 toColorScheme() 至 1.9.0 仍取 primary.get(10)，实测
        // 对比度 13.2（近黑压浅块）。现代规范是 tone 30/90，对比度 7.2。
        final palettes = palettesOf(0xFF2E59A7);
        for (final brightness in Brightness.values) {
          final scheme = AppColorScheme.resolve(
            brightness,
            AccentPalette.system(palettes),
          );
          final legacyTone = palettes.primary.get(brightness == .dark ? 90 : 10);
          final modernTone = palettes.primary.get(brightness == .dark ? 90 : 30);
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

      test('是纯正 M3：结构性角色跟着壁纸染色，不套用灰阶', () {
        // 只有默认的黑白档是本仓自己的配色，系统档一个角色都不改。
        for (final brightness in Brightness.values) {
          final scheme = AppColorScheme.resolve(
            brightness,
            AccentPalette.system(palettesOf(0xFF2E59A7)),
          );
          expect(
            _structuralOf(scheme),
            isNot(
              _structuralOf(
                AppColorScheme.resolve(
                  brightness,
                  const AccentPalette.neutral(),
                ),
              ),
            ),
            reason: '系统档的表面色不该等于灰阶档',
          );
          expect(_isGray(scheme.surface), isFalse, reason: 'surface 应带色相');
          expect(_isGray(scheme.tertiary), isFalse, reason: 'tertiary 应带色相');
          expect(scheme.surfaceTint, scheme.primary, reason: '高程染色应为标准值');
        }
      });
    });

    test('结构性角色清单与断言辅助保持同步', () {
      expect(
        _structuralOf(
          AppColorScheme.resolve(.light, const AccentPalette.neutral()),
        ).keys,
        _structuralRoles,
      );
    });
  });
}
