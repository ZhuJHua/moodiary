import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show
        DynamicColor,
        DynamicScheme,
        Hct,
        MaterialDynamicColors,
        SchemeMonochrome,
        SchemeTonalSpot;

/// 强调色来源。只有两种取色路径：给了种子就走 [SchemeTonalSpot]，没给就走
/// [SchemeMonochrome]。
///
/// 系统档与自定义档在这里是**同一条路** —— `dynamic_color` 只负责交出一个系统主题色，
/// 交出来之后它和用户自己挑的颜色没有任何区别。代价是壁纸的饱和度会按 tone-40
/// 重算：实测壁纸 `#B3261E` 的 primary 从 `#B4271F`（红）变成 `#904A42`（褐红）。
@immutable
class MuiAccent {
  const MuiAccent.neutral() : seed = null;

  const MuiAccent.seeded(Color this.seed);

  /// 种子色。null = 无彩档。
  final Color? seed;

  bool get isNeutral => seed == null;
}

/// 配色的唯一入口 —— 产物直接就是 material 的 [ColorScheme]。
///
/// 两条路径都是 MCU 的标准 scheme，逐角色 [MaterialDynamicColors] 解析，本仓不覆盖
/// 任何一个角色：
///   * **无彩** —— [SchemeMonochrome]（chroma 钉 0，`HctSolver` 短路后种子被完全
///     丢弃，所以传什么种子都一样）。
///   * **有彩** —— [SchemeTonalSpot]，与 `ColorScheme.fromSeed` 的默认路径等价。
///     系统档与自定义档共用它，区别只在种子从哪来。
///
/// **必须逐角色显式赋值**，禁止 `ColorScheme.fromSeed(...).copyWith(...)`：46 个角色
/// 里只有 9 个是 required，其余漏填不会编译失败，而是坍塌式回退
/// （`surfaceContainer* ?? surface`、`tertiary ?? secondary`、
/// `outlineVariant ?? onBackground`），症状是整条容器阶梯塌成同一个 surface。
ColorScheme resolveColorScheme(Brightness brightness, MuiAccent accent) {
  final seed = accent.seed;
  final scheme = seed == null
      ? SchemeMonochrome(
          sourceColorHct: Hct.fromInt(0xFF000000),
          isDark: brightness == Brightness.dark,
          contrastLevel: 0,
        )
      // 与 `ColorScheme.fromSeed(seedColor: seed, brightness: b)` 逐角色等价：
      // SDK 那条路（color_scheme.dart:2186）对 tonalSpot 建的就是这个 scheme。
      : SchemeTonalSpot(
          sourceColorHct: Hct.fromInt(seed.toARGB32()),
          isDark: brightness == Brightness.dark,
          contrastLevel: 0,
        );
  return _fromDynamicScheme(scheme, brightness);
}

ColorScheme _fromDynamicScheme(DynamicScheme scheme, Brightness brightness) {
  Color of(DynamicColor role) => Color(role.getArgb(scheme));
  final primary = of(MaterialDynamicColors.primary);
  return ColorScheme(
    brightness: brightness,

    primary: primary,
    onPrimary: of(MaterialDynamicColors.onPrimary),
    primaryContainer: of(MaterialDynamicColors.primaryContainer),
    onPrimaryContainer: of(MaterialDynamicColors.onPrimaryContainer),
    primaryFixed: of(MaterialDynamicColors.primaryFixed),
    primaryFixedDim: of(MaterialDynamicColors.primaryFixedDim),
    onPrimaryFixed: of(MaterialDynamicColors.onPrimaryFixed),
    onPrimaryFixedVariant: of(MaterialDynamicColors.onPrimaryFixedVariant),

    secondary: of(MaterialDynamicColors.secondary),
    onSecondary: of(MaterialDynamicColors.onSecondary),
    secondaryContainer: of(MaterialDynamicColors.secondaryContainer),
    onSecondaryContainer: of(MaterialDynamicColors.onSecondaryContainer),
    secondaryFixed: of(MaterialDynamicColors.secondaryFixed),
    secondaryFixedDim: of(MaterialDynamicColors.secondaryFixedDim),
    onSecondaryFixed: of(MaterialDynamicColors.onSecondaryFixed),
    onSecondaryFixedVariant: of(MaterialDynamicColors.onSecondaryFixedVariant),

    tertiary: of(MaterialDynamicColors.tertiary),
    onTertiary: of(MaterialDynamicColors.onTertiary),
    tertiaryContainer: of(MaterialDynamicColors.tertiaryContainer),
    onTertiaryContainer: of(MaterialDynamicColors.onTertiaryContainer),
    tertiaryFixed: of(MaterialDynamicColors.tertiaryFixed),
    tertiaryFixedDim: of(MaterialDynamicColors.tertiaryFixedDim),
    onTertiaryFixed: of(MaterialDynamicColors.onTertiaryFixed),
    onTertiaryFixedVariant: of(MaterialDynamicColors.onTertiaryFixedVariant),

    error: of(MaterialDynamicColors.error),
    onError: of(MaterialDynamicColors.onError),
    errorContainer: of(MaterialDynamicColors.errorContainer),
    onErrorContainer: of(MaterialDynamicColors.onErrorContainer),

    surface: of(MaterialDynamicColors.surface),
    onSurface: of(MaterialDynamicColors.onSurface),
    surfaceDim: of(MaterialDynamicColors.surfaceDim),
    surfaceBright: of(MaterialDynamicColors.surfaceBright),
    surfaceContainerLowest: of(MaterialDynamicColors.surfaceContainerLowest),
    surfaceContainerLow: of(MaterialDynamicColors.surfaceContainerLow),
    surfaceContainer: of(MaterialDynamicColors.surfaceContainer),
    surfaceContainerHigh: of(MaterialDynamicColors.surfaceContainerHigh),
    surfaceContainerHighest: of(MaterialDynamicColors.surfaceContainerHighest),
    onSurfaceVariant: of(MaterialDynamicColors.onSurfaceVariant),

    outline: of(MaterialDynamicColors.outline),
    outlineVariant: of(MaterialDynamicColors.outlineVariant),

    inverseSurface: of(MaterialDynamicColors.inverseSurface),
    onInverseSurface: of(MaterialDynamicColors.inverseOnSurface),
    inversePrimary: of(MaterialDynamicColors.inversePrimary),

    shadow: of(MaterialDynamicColors.shadow),
    scrim: of(MaterialDynamicColors.scrim),
    // SDK 用的是 primary 而不是 MaterialDynamicColors.surfaceTint
    // （color_scheme.dart:456）。tonalSpot 下两者巧合相同，monochrome 下差一档。
    surfaceTint: primary,
    // M3 已废弃，mui 组件不许用。仍填是因为不填会坍塌成 surface，而第三方 widget 还在读。
    // ignore: deprecated_member_use
    surfaceVariant: of(MaterialDynamicColors.surfaceVariant),
  );
}
