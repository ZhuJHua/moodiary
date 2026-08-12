import 'package:flutter/widgets.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show
        DynamicColor,
        DynamicScheme,
        Hct,
        MaterialDynamicColors,
        SchemeMonochrome,
        SchemeTonalSpot;
import 'package:mui/src/themes/value.dart';

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

/// 全仓唯一的配色真源。
///
/// 角色名与 M3 `ColorScheme` **逐个同名**，这是刻意的：`mui_material_bridge.dart`
/// 的投影因此是 1:1 映射而不是语义翻译，共存期两棵主题树不可能漂。
/// 另加两个 mui 自有槽位 [ring] / [selection]。
///
/// 两条路径都是 MCU 的标准 scheme，逐角色 [MaterialDynamicColors] 解析，本仓不覆盖
/// 任何一个角色：
///   * **无彩** —— [SchemeMonochrome]（chroma 钉 0，`HctSolver` 短路后种子被完全
///     丢弃，所以传什么种子都一样）。
///   * **有彩** —— [SchemeTonalSpot]，与 `ColorScheme.fromSeed` 的默认路径等价。
///     系统档与自定义档共用它，区别只在种子从哪来。
@immutable
class MuiColorScheme with MuiValue {
  const MuiColorScheme({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.onPrimaryFixedVariant,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.onSecondaryFixedVariant,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixed,
    required this.onTertiaryFixedVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.surface,
    required this.onSurface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.shadow,
    required this.scrim,
    required this.surfaceTint,
    required this.surfaceVariant,
    required this.ring,
    required this.selection,
  });

  final Brightness brightness;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;

  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  final Color surface;
  final Color onSurface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurfaceVariant;

  final Color outline;
  final Color outlineVariant;

  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  final Color shadow;

  /// 遮罩基色，**不含 alpha**（与 M3 一致，调用点自己乘）。
  final Color scrim;

  final Color surfaceTint;

  /// M3 已废弃的角色，mui 组件**不许用**。留着只为了让投影完整 ——
  /// material 的 `ColorScheme` 至今仍带着它，不填就会坍塌成 `surface`，
  /// 而仍有第三方 widget 在读。
  final Color surfaceVariant;

  /// 焦点环。独立槽位不复用 [outline] —— 焦点用什么色是独立决策。
  final Color ring;

  /// 文本选中底色。半透明存储：它画在文字下方且要叠在任意背景上。
  final Color selection;

  @override
  List<Object?> get props => [
    brightness,
    primary,
    onPrimary,
    primaryContainer,
    onPrimaryContainer,
    primaryFixed,
    primaryFixedDim,
    onPrimaryFixed,
    onPrimaryFixedVariant,
    secondary,
    onSecondary,
    secondaryContainer,
    onSecondaryContainer,
    secondaryFixed,
    secondaryFixedDim,
    onSecondaryFixed,
    onSecondaryFixedVariant,
    tertiary,
    onTertiary,
    tertiaryContainer,
    onTertiaryContainer,
    tertiaryFixed,
    tertiaryFixedDim,
    onTertiaryFixed,
    onTertiaryFixedVariant,
    error,
    onError,
    errorContainer,
    onErrorContainer,
    surface,
    onSurface,
    surfaceDim,
    surfaceBright,
    surfaceContainerLowest,
    surfaceContainerLow,
    surfaceContainer,
    surfaceContainerHigh,
    surfaceContainerHighest,
    onSurfaceVariant,
    outline,
    outlineVariant,
    inverseSurface,
    onInverseSurface,
    inversePrimary,
    shadow,
    scrim,
    surfaceTint,
    surfaceVariant,
    ring,
    selection,
  ];

  /// 配色的唯一入口。
  static MuiColorScheme resolve(Brightness brightness, MuiAccent accent) {
    final seed = accent.seed;
    if (seed == null) return _neutral(brightness);
    // 与 `ColorScheme.fromSeed(seedColor: seed, brightness: b)` 逐角色等价：
    // SDK 那条路（color_scheme.dart:2186）对 tonalSpot 建的就是这个 scheme。
    return _fromDynamicScheme(
      SchemeTonalSpot(
        sourceColorHct: Hct.fromInt(seed.toARGB32()),
        isDark: brightness == .dark,
        contrastLevel: 0,
      ),
      brightness,
    );
  }

  /// 无彩档。`monochrome` 变体把 chroma 钉为 0，`HctSolver.solveToInt` 随即短路并
  /// 丢弃色相 —— 三个不同种子实测输出逐字节相同，所以种子传什么都一样。
  ///
  /// 注意这一档下 `primaryContainer` 是**高对比**容器（浅色档近黑、与 surface 差
  /// 8.6:1），不是弱填充。选中态想要弱填充请用 `surfaceContainerHighest`。
  static MuiColorScheme _neutral(Brightness brightness) => _fromDynamicScheme(
    SchemeMonochrome(
      sourceColorHct: Hct.fromInt(0xFF000000),
      isDark: brightness == .dark,
      contrastLevel: 0,
    ),
    brightness,
  );

  static MuiColorScheme _fromDynamicScheme(
    DynamicScheme scheme,
    Brightness brightness,
  ) {
    Color of(DynamicColor role) => Color(role.getArgb(scheme));
    final primary = of(MaterialDynamicColors.primary);
    return MuiColorScheme(
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
      onSecondaryFixedVariant: of(
        MaterialDynamicColors.onSecondaryFixedVariant,
      ),

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
      surfaceContainerHighest: of(
        MaterialDynamicColors.surfaceContainerHighest,
      ),
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
      surfaceVariant: of(MaterialDynamicColors.surfaceVariant),

      ring: primary,
      selection: primary.withValues(alpha: 0.25),
    );
  }

  static MuiColorScheme lerp(MuiColorScheme a, MuiColorScheme b, double t) {
    if (identical(a, b)) return a;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return MuiColorScheme(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      primary: c(a.primary, b.primary),
      onPrimary: c(a.onPrimary, b.onPrimary),
      primaryContainer: c(a.primaryContainer, b.primaryContainer),
      onPrimaryContainer: c(a.onPrimaryContainer, b.onPrimaryContainer),
      primaryFixed: c(a.primaryFixed, b.primaryFixed),
      primaryFixedDim: c(a.primaryFixedDim, b.primaryFixedDim),
      onPrimaryFixed: c(a.onPrimaryFixed, b.onPrimaryFixed),
      onPrimaryFixedVariant: c(
        a.onPrimaryFixedVariant,
        b.onPrimaryFixedVariant,
      ),
      secondary: c(a.secondary, b.secondary),
      onSecondary: c(a.onSecondary, b.onSecondary),
      secondaryContainer: c(a.secondaryContainer, b.secondaryContainer),
      onSecondaryContainer: c(a.onSecondaryContainer, b.onSecondaryContainer),
      secondaryFixed: c(a.secondaryFixed, b.secondaryFixed),
      secondaryFixedDim: c(a.secondaryFixedDim, b.secondaryFixedDim),
      onSecondaryFixed: c(a.onSecondaryFixed, b.onSecondaryFixed),
      onSecondaryFixedVariant: c(
        a.onSecondaryFixedVariant,
        b.onSecondaryFixedVariant,
      ),
      tertiary: c(a.tertiary, b.tertiary),
      onTertiary: c(a.onTertiary, b.onTertiary),
      tertiaryContainer: c(a.tertiaryContainer, b.tertiaryContainer),
      onTertiaryContainer: c(a.onTertiaryContainer, b.onTertiaryContainer),
      tertiaryFixed: c(a.tertiaryFixed, b.tertiaryFixed),
      tertiaryFixedDim: c(a.tertiaryFixedDim, b.tertiaryFixedDim),
      onTertiaryFixed: c(a.onTertiaryFixed, b.onTertiaryFixed),
      onTertiaryFixedVariant: c(
        a.onTertiaryFixedVariant,
        b.onTertiaryFixedVariant,
      ),
      error: c(a.error, b.error),
      onError: c(a.onError, b.onError),
      errorContainer: c(a.errorContainer, b.errorContainer),
      onErrorContainer: c(a.onErrorContainer, b.onErrorContainer),
      surface: c(a.surface, b.surface),
      onSurface: c(a.onSurface, b.onSurface),
      surfaceDim: c(a.surfaceDim, b.surfaceDim),
      surfaceBright: c(a.surfaceBright, b.surfaceBright),
      surfaceContainerLowest: c(
        a.surfaceContainerLowest,
        b.surfaceContainerLowest,
      ),
      surfaceContainerLow: c(a.surfaceContainerLow, b.surfaceContainerLow),
      surfaceContainer: c(a.surfaceContainer, b.surfaceContainer),
      surfaceContainerHigh: c(a.surfaceContainerHigh, b.surfaceContainerHigh),
      surfaceContainerHighest: c(
        a.surfaceContainerHighest,
        b.surfaceContainerHighest,
      ),
      onSurfaceVariant: c(a.onSurfaceVariant, b.onSurfaceVariant),
      outline: c(a.outline, b.outline),
      outlineVariant: c(a.outlineVariant, b.outlineVariant),
      inverseSurface: c(a.inverseSurface, b.inverseSurface),
      onInverseSurface: c(a.onInverseSurface, b.onInverseSurface),
      inversePrimary: c(a.inversePrimary, b.inversePrimary),
      shadow: c(a.shadow, b.shadow),
      scrim: c(a.scrim, b.scrim),
      surfaceTint: c(a.surfaceTint, b.surfaceTint),
      surfaceVariant: c(a.surfaceVariant, b.surfaceVariant),
      ring: c(a.ring, b.ring),
      selection: c(a.selection, b.selection),
    );
  }
}
