import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:mui/mui.dart';

/// 三档配色现在全部是 MCU 的标准 scheme，本仓不覆盖任何角色 —— 所以投影的正确性
/// 可以直接对着 SDK 自己的 `ColorScheme.fromSeed` 断言，不需要黄金表。
///
/// 这两条同时是**「SDK 新增了 ColorScheme 角色」的探测器**：`ColorScheme.==` 比的是
/// 它自己的全部字段，而 `fromSeed` 会把新角色填好、投影不会。升级 Flutter 后这里
/// 红了，多半是要往 [materialColorSchemeFrom] 与 [MuiColorScheme] 各补一个角色。
ColorScheme _sdkNeutral(Brightness brightness) => ColorScheme.fromSeed(
  seedColor: const Color(0xFF000000),
  brightness: brightness,
  dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
);

void main() {
  group('materialColorSchemeFrom', () {
    for (final brightness in Brightness.values) {
      test('$brightness 无彩档与 SchemeMonochrome 逐字段相同', () {
        expect(
          materialColorSchemeFrom(
            MuiColorScheme.resolve(brightness, const MuiAccent.neutral()),
          ),
          _sdkNeutral(brightness),
        );
      });

      test('$brightness 自定义档与 ColorScheme.fromSeed 逐字段相同', () {
        for (final seed in const [
          Color(0xFF2E59A7),
          Color(0xFFECD452),
          Color(0xFFA72126),
        ]) {
          expect(
            materialColorSchemeFrom(
              MuiColorScheme.resolve(brightness, MuiAccent.seeded(seed)),
            ),
            ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
            reason: '种子 $seed 的投影与 SDK 不一致',
          );
        }
      });
    }
  });

  group('materialThemeFrom', () {
    final theme = materialThemeFrom(MuiThemeData(brightness: .light));

    test('水波纹关掉，但按压/悬停/聚焦反馈还在', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.highlightColor.a, greaterThan(0));
      expect(theme.hoverColor.a, greaterThan(0));
      expect(theme.focusColor.a, greaterThan(0));
    });

    test('容器类阴影归零', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.chipTheme.elevation, 0);
      // 弹窗例外：它浮在遮罩上，投影是层级信息。
      expect(theme.dialogTheme.elevation, 8);
    });

    test('圆角落在 mui 的四档上', () {
      const radii = MuiRadii();
      BorderRadius radiusOf(ShapeBorder? shape) =>
          (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;

      expect(radiusOf(theme.cardTheme.shape).topLeft.x, radii.lg);
      expect(radiusOf(theme.dialogTheme.shape).topLeft.x, radii.xl);
      expect(radiusOf(theme.popupMenuTheme.shape).topLeft.x, radii.lg);
      expect(radiusOf(theme.bottomSheetTheme.shape).topLeft.x, radii.xl);
      expect(radiusOf(theme.bottomSheetTheme.shape).bottomLeft.x, 0);
    });

    test('输入框装饰承接 form.dart 的圆角填充式范式', () {
      final d = theme.inputDecorationTheme;
      expect(d.filled, isTrue);
      expect(d.fillColor, theme.colorScheme.surfaceContainerHighest);
      expect(
        (d.enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
      final focused = d.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, theme.colorScheme.primary);
      expect(focused.borderSide.width, const MuiBorders().ring);
      expect(focused.borderRadius.topLeft.x, const MuiRadii().md);
    });

    test('排版整块替换而非 merge —— inherit 为 false 才做得到', () {
      final mui = MuiThemeData(brightness: .light);
      expect(theme.textTheme.bodyMedium, mui.typography.bodyMedium.onSurface);
      // M3 2021 的 headline 三级都是 Regular，强调档不进 material 的 TextTheme。
      expect(theme.textTheme.headlineLarge!.fontWeight, FontWeight.w400);
    });

    test('字号档投影进 material 的 textTheme', () {
      double bodyAt(MuiTextSize size) => materialThemeFrom(
        MuiThemeData(brightness: .light, textSize: size),
      ).textTheme.bodyMedium!.fontSize!;

      // large 是基准，与 M3 原值一致；两侧各档单调。
      expect(bodyAt(MuiTextSize.large), 14);
      expect(bodyAt(MuiTextSize.xSmall), lessThan(bodyAt(MuiTextSize.large)));
      expect(bodyAt(MuiTextSize.xxxLarge), greaterThan(bodyAt(.large)));
      final all = MuiTextSize.values.map(bodyAt).toList();
      expect(all, orderedEquals(all.toList()..sort()));
    });

    test('顶栏滚动态不变色不投影', () {
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('SDK 那几个绕开 colorScheme 的缺省值都被色板接管', () {
      final cs = theme.colorScheme;
      // 这五个 SDK 缺省值是绝对色（0xDD000000 / black54 / black60 / black38 /
      // Colors.black），与色板无关；断言它们已落回角色。
      expect(theme.iconTheme.color, cs.onSurface);
      expect(theme.iconTheme.color, isNot(const Color(0xDD000000)));
      expect(theme.primaryIconTheme.color, cs.onPrimary);
      expect(theme.hintColor, cs.onSurfaceVariant);
      expect(theme.unselectedWidgetColor, cs.onSurfaceVariant);
      expect(theme.disabledColor.a, closeTo(const MuiStateTokens().disabledOpacity, 0.01));
      expect(theme.shadowColor, cs.shadow);
      // 分隔线：SDK 的 M3 缺省是 outline，规范里是 outlineVariant，重了一档。
      expect(theme.dividerColor, cs.outlineVariant);
      expect(theme.dividerColor, isNot(cs.outline));
    });

    test('图标只投颜色不投尺寸 —— 尺寸仍由 IconThemeData.fallback 兜到 24', () {
      expect(theme.iconTheme.size, isNull);
    });

    test('文本选中态用 mui 的自有槽位', () {
      final mui = MuiThemeData(brightness: .light);
      expect(theme.textSelectionTheme.selectionColor, mui.colors.selection);
      expect(theme.textSelectionTheme.cursorColor, mui.colors.ring);
    });

    group('systemOverlayStyleFrom', () {
      test('图标明暗跟主题亮度走，且 iOS/Android 两个字段是反的', () {
        final light = systemOverlayStyleFrom(MuiThemeData(brightness: .light));
        expect(light.statusBarIconBrightness, Brightness.dark);
        expect(light.statusBarBrightness, Brightness.light);
        expect(light.systemNavigationBarIconBrightness, Brightness.dark);

        final dark = systemOverlayStyleFrom(MuiThemeData(brightness: .dark));
        expect(dark.statusBarIconBrightness, Brightness.light);
        expect(dark.statusBarBrightness, Brightness.dark);
        expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      });

      test('两条栏都透明且不让系统补对比度（edge-to-edge 的前提）', () {
        final style = systemOverlayStyleFrom(MuiThemeData(brightness: .light));
        expect(style.statusBarColor, Colors.transparent);
        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.systemStatusBarContrastEnforced, isFalse);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      });

      test('顶栏拿的是同一个值 —— 有无 AppBar 的页面不许出现两种状态栏', () {
        expect(
          theme.appBarTheme.systemOverlayStyle,
          systemOverlayStyleFrom(MuiThemeData(brightness: .light)),
        );
      });
    });
  });
}
