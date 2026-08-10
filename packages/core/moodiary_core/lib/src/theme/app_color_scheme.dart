import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show
        DynamicColor,
        DynamicScheme,
        Hct,
        MaterialDynamicColors,
        TonalPalette,
        Variant;

/// 灰阶槽位表。浅深各一套，全部严格 `R == G == B`。
///
/// 槽位按用途命名而非按 M3 角色命名 —— 一个槽位可能同时喂给几个角色（[fill] 就同时
/// 是 primaryContainer 与 secondaryContainer），反过来命名会读不通。
class NeutralRamp {
  /// 页面地色（surface / surfaceBright 的浅色档）。
  final Color page;

  /// 比地色更沉的一档，深色档的 surfaceBright 靠它抬起来。
  final Color bright;

  /// M3 语义里最暗的表面。
  final Color dim;

  final Color lowest;

  /// 日记卡片的弱填充。与 [page] 只差一档，卡片靠它 + 发丝描边分离，不靠阴影。
  final Color cardFill;

  final Color muted;
  final Color raised;
  final Color highest;

  /// 装饰性发丝分隔线（outlineVariant）。对比度刻意压到 1.3 量级，
  /// 只允许画分割线与卡片轮廓；任何可交互边界必须用 [border]。
  final Color hairline;

  /// 可交互控件边界（outline）。按 WCAG 1.4.11 反解，静态容器上过 3:1。
  final Color border;

  /// 正文（onSurface）。
  final Color ink;

  /// 次级文字（onSurfaceVariant）。全仓引用最密的角色，按「压在最深容器上仍过 AA」反解。
  final Color mutedInk;

  /// 无彩档的强调墨色（primary）。与 [ink] 几乎同值 —— 无彩档的强调靠实心填充 +
  /// 反色前景，不靠色相。
  final Color accentInk;

  /// 落在 [accentInk] 上的前景（onPrimary）。
  final Color onAccentInk;

  /// 无彩档的强调容器（primary/secondaryContainer）。刻意脱离 [highest]，
  /// 否则「选中 vs 未选中」在纯灰下会塌成同一块。
  final Color fill;

  final Color inverse;
  final Color onInverse;

  const NeutralRamp._({
    required this.page,
    required this.bright,
    required this.dim,
    required this.lowest,
    required this.cardFill,
    required this.muted,
    required this.raised,
    required this.highest,
    required this.hairline,
    required this.border,
    required this.ink,
    required this.mutedInk,
    required this.accentInk,
    required this.onAccentInk,
    required this.fill,
    required this.inverse,
    required this.onInverse,
  });

  static const NeutralRamp light = ._(
    page: Color(0xFFFFFFFF),
    bright: Color(0xFFFFFFFF),
    dim: Color(0xFFE0E0E0),
    lowest: Color(0xFFFFFFFF),
    cardFill: Color(0xFFFAFAFA),
    muted: Color(0xFFF5F5F5),
    raised: Color(0xFFEFEFEF),
    highest: Color(0xFFE8E8E8),
    hairline: Color(0xFFDCDCDC),
    border: Color(0xFF858585),
    ink: Color(0xFF0A0A0A),
    mutedInk: Color(0xFF666666),
    accentInk: Color(0xFF171717),
    onAccentInk: Color(0xFFFAFAFA),
    fill: Color(0xFFD4D4D4),
    inverse: Color(0xFF262626),
    onInverse: Color(0xFFFAFAFA),
  );

  static const NeutralRamp dark = ._(
    page: Color(0xFF0A0A0A),
    bright: Color(0xFF2E2E2E),
    dim: Color(0xFF0A0A0A),
    lowest: Color(0xFF000000),
    cardFill: Color(0xFF141414),
    muted: Color(0xFF171717),
    raised: Color(0xFF1F1F1F),
    highest: Color(0xFF262626),
    hairline: Color(0xFF333333),
    border: Color(0xFF7A7A7A),
    ink: Color(0xFFFAFAFA),
    mutedInk: Color(0xFFA3A3A3),
    accentInk: Color(0xFFFAFAFA),
    onAccentInk: Color(0xFF171717),
    fill: Color(0xFF3A3A3A),
    inverse: Color(0xFFE5E5E5),
    onInverse: Color(0xFF171717),
  );

  static NeutralRamp of(Brightness brightness) =>
      brightness == .light ? light : dark;
}

/// 强调色来源。持久化的是 index，改动顺序会改掉老用户的配色。
enum ThemeAccentMode {
  /// 纯灰度。默认档。
  neutral,

  /// 取自系统壁纸。仅 Android 12+ 拿得到，其余平台该档不可选。
  system,

  /// 用户在取色器里挑的颜色。
  custom,
}

/// 系统给的五条 tonal palette。
///
/// 自己声明而不用 MCU 的类型：`CorePalette` 在 0.13.0 已废弃，而替代它的 `CorePalettes`
/// 没有从 barrel 导出（只在 `palettes/core_palettes.dart` 里），深引私有路径不如自己拿着。
/// 在 dynamic_color 的边界上就地拆包，废弃类型不渗进仓里。
class SystemPalettes {
  final TonalPalette primary;
  final TonalPalette secondary;
  final TonalPalette tertiary;
  final TonalPalette neutral;
  final TonalPalette neutralVariant;

  const SystemPalettes({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
  });
}

/// 强调色来源。三态各走一条不同的取色路径，见 [AppColorScheme.resolve]。
class AccentPalette {
  /// 自定义档：用户挑的种子色。
  final Color? seed;

  /// 系统档：**OS 给的整套 tonal palette**，不是从某个颜色重推的。
  ///
  /// 差别是肉眼级的：拿 `primary.get(40)` 当种子重推会按那个 tone-40 色重算 chroma，
  /// 把壁纸原本的饱和度丢掉 —— 实测壁纸 `#B3261E` 重推后 primary 从 `#B4271F`（红）
  /// 变成 `#904A42`（褐红），ΔE 34.4。所以系统档必须端着原盘走。
  final SystemPalettes? system;

  const AccentPalette.neutral() : seed = null, system = null;

  const AccentPalette.seeded(Color this.seed) : system = null;

  const AccentPalette.system(SystemPalettes this.system) : seed = null;

  bool get isNeutral => seed == null && system == null;
}

/// 全仓唯一的 [ColorScheme] 生成点。
///
/// 三档互不相干，各走各的路：
///   * **无彩** —— 本仓自己的 [NeutralRamp]，把 M3 的角色映射整个换掉。这是设计，
///     不是 M3 配色，见 [_neutral]。
///   * **系统** —— OS 的五条盘 + 标准 [MaterialDynamicColors]，45 个角色全部原样，
///     一个都不改，见 [_system]。
///   * **自定义** —— 裸的 [ColorScheme.fromSeed]，一个覆盖参数都不传。
///
/// 换句话说：**只有默认的黑白档是「我们的」配色，另外两档是纯正 Material 3。**
abstract final class AppColorScheme {
  static ColorScheme resolve(Brightness brightness, AccentPalette accent) {
    final system = accent.system;
    if (system != null) return _system(system, brightness);

    final seed = accent.seed;
    if (seed != null) {
      return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    }

    return _neutral(brightness);
  }

  /// 系统档：把 OS 交上来的五条 tonal palette 直接喂给 [DynamicScheme]，再用标准
  /// [MaterialDynamicColors] 解析每一个角色。
  ///
  /// 不走 `dynamic_color` 的 `toColorScheme()`：那条路用的是 legacy 的
  /// `Scheme.lightFromCorePalette`，`on*Container` 取 `primary.get(10)`（实测
  /// `#001A43`，对比度 13.2），而标准规范是 tone 30/90（`#104491`，7.2）；
  /// 它的 surface 阶梯也是从 tone-40 色重推的，不是 OS 的中性盘。
  /// dynamic_color 自己的 `TODO(#363)` 说的正是要迁到这里这条路。
  static ColorScheme _system(SystemPalettes palettes, Brightness brightness) {
    final scheme = DynamicScheme(
      sourceColorHct: Hct.fromInt(palettes.primary.get(40)),
      variant: Variant.tonalSpot,
      isDark: brightness == .dark,
      primaryPalette: palettes.primary,
      secondaryPalette: palettes.secondary,
      tertiaryPalette: palettes.tertiary,
      neutralPalette: palettes.neutral,
      neutralVariantPalette: palettes.neutralVariant,
    );
    Color of(DynamicColor role) => Color(role.getArgb(scheme));

    // 逐个角色显式取值，而不是让 fromSeed 兜底 —— 兜底会用「从 tone40 色重推的盘」
    // 填补漏掉的角色，那正是要避免的漂移，而且不会有任何报错。
    return ColorScheme.fromSeed(
      seedColor: Color(palettes.primary.get(40)),
      brightness: brightness,
      primary: of(MaterialDynamicColors.primary),
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
      outline: of(MaterialDynamicColors.outline),
      outlineVariant: of(MaterialDynamicColors.outlineVariant),
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
      inverseSurface: of(MaterialDynamicColors.inverseSurface),
      onInverseSurface: of(MaterialDynamicColors.inverseOnSurface),
      inversePrimary: of(MaterialDynamicColors.inversePrimary),
      shadow: of(MaterialDynamicColors.shadow),
      scrim: of(MaterialDynamicColors.scrim),
      surfaceTint: of(MaterialDynamicColors.surfaceTint),
    );
  }

  /// 无彩档：`monochrome` 变体打底（chroma 钉 0 后 `HctSolver.solveToInt` 直接短路
  /// 返回灰阶，种子色被完全丢弃 —— 三个不同种子实测输出逐字节相同，所以种子传什么
  /// 都一样），再用 [NeutralRamp] 把角色映射整个换掉。
  ///
  /// 底座仍走 [ColorScheme.fromSeed] 是为了兜底：漏覆盖的角色最坏是个没调过的灰，
  /// 不可能漏出颜色。
  static ColorScheme _neutral(Brightness brightness) {
    final r = NeutralRamp.of(brightness);
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF000000),
      brightness: brightness,
      dynamicSchemeVariant: .monochrome,

      surface: r.page,
      surfaceBright: r.bright,
      surfaceDim: r.dim,
      surfaceContainerLowest: r.lowest,
      surfaceContainerLow: r.cardFill,
      surfaceContainer: r.muted,
      surfaceContainerHigh: r.raised,
      surfaceContainerHighest: r.highest,
      onSurface: r.ink,
      onSurfaceVariant: r.mutedInk,
      outline: r.border,
      outlineVariant: r.hairline,
      inverseSurface: r.inverse,
      onInverseSurface: r.onInverse,

      // M3 的高程染色在这一档没有意义：表面阶梯已经钉死，再叠一层只会让卡片偏色。
      surfaceTint: Colors.transparent,

      primary: r.accentInk,
      onPrimary: r.onAccentInk,
      primaryContainer: r.fill,
      onPrimaryContainer: r.accentInk,
      secondary: r.accentInk,
      onSecondary: r.onAccentInk,
      secondaryContainer: r.fill,
      onSecondaryContainer: r.accentInk,
      tertiary: r.accentInk,
      onTertiary: r.onAccentInk,
      tertiaryContainer: r.fill,
      onTertiaryContainer: r.accentInk,
      inversePrimary: r.border,
    );
  }
}
