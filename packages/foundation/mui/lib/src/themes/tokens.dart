import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:mui/src/themes/value.dart';

/// 圆角档。承接 `AppBorderRadius` 的 8/12/16/24，另加胶囊态。
///
/// 分配：按钮与输入框 [md]、卡片与菜单 [lg]、弹层 [xl]、chip 与底栏 [full]。
@immutable
class MuiRadii with MuiValue {
  const MuiRadii({
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.full = 999,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  @override
  List<Object?> get props => [sm, md, lg, xl, full];

  static MuiRadii lerp(MuiRadii a, MuiRadii b, double t) => MuiRadii(
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    full: lerpDouble(a.full, b.full, t)!,
  );
}

/// 间距档 + 两个几何常量。
///
/// [minTapTarget] 必须自带：`kMinInteractiveDimension` 定义在
/// `widgets/constants.dart`，而那个文件不在 `widgets.dart` 的 export 列表里。
@immutable
class MuiSpacing with MuiValue {
  const MuiSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.pagePadding = const .symmetric(horizontal: 16),
    this.minTapTarget = 48,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final EdgeInsets pagePadding;
  final double minTapTarget;

  @override
  List<Object?> get props => [xs, sm, md, lg, xl, pagePadding, minTapTarget];

  static MuiSpacing lerp(MuiSpacing a, MuiSpacing b, double t) => MuiSpacing(
    xs: lerpDouble(a.xs, b.xs, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    pagePadding: EdgeInsets.lerp(a.pagePadding, b.pagePadding, t)!,
    minTapTarget: lerpDouble(a.minTapTarget, b.minTapTarget, t)!,
  );
}

/// 时长与曲线。顶替 `Durations` / `Easing` —— 那两个类只存在于 material。
///
/// [enter] / [exit] 刻意不对称，取自现有 `alert.dart` 与 `menu.dart` 的 200/130ms。
@immutable
class MuiMotion with MuiValue {
  const MuiMotion({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 250),
    this.slow = const Duration(milliseconds: 400),
    this.enter = const Duration(milliseconds: 200),
    this.exit = const Duration(milliseconds: 130),
    this.themeSwitch = const Duration(milliseconds: 200),
    this.standard = const Cubic(0.2, 0, 0, 1),
    this.emphasized = const Cubic(0.05, 0.7, 0.1, 1),
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
  });

  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Duration enter;
  final Duration exit;

  /// 深浅色与三态配色切换的补间时长。
  ///
  /// **必须与 material 侧 `Material` 内那层 `AnimatedDefaultTextStyle` 的
  /// `kThemeChangeDuration` 保持一致**（同为 200ms）：共存期同屏两套子树，
  /// 时长不一致会看到 material 区域的文字还在渐变、mui 区域已经跳完。
  final Duration themeSwitch;

  final Curve standard;
  final Curve emphasized;
  final Curve enterCurve;
  final Curve exitCurve;

  @override
  List<Object?> get props => [
    fast,
    normal,
    slow,
    enter,
    exit,
    themeSwitch,
    standard,
    emphasized,
    enterCurve,
    exitCurve,
  ];

  /// 曲线与时长不插值：中途换一半的时长没有意义，硬切即可。
  static MuiMotion lerp(MuiMotion a, MuiMotion b, double t) => t < 0.5 ? a : b;
}

/// 描边宽度档。
@immutable
class MuiBorders with MuiValue {
  const MuiBorders({
    this.hairline = 0.5,
    this.thin = 1,
    this.ring = 1.5,
    this.ringOffset = 3,
  });

  /// 装饰性发丝线。画在 `outlineVariant` 上。
  ///
  /// 需要「恰好一个物理像素」的场景（玻璃面描边）用
  /// `1 / MediaQuery.devicePixelRatioOf(context)` 现算，不要用这个常量 ——
  /// 写死 0.5 在 3x 屏上是 1.5 个物理像素，粗得能看出来。
  final double hairline;

  final double thin;

  /// 焦点环宽度。承接 `form.dart` 现有的 focusedBorder。
  final double ring;

  /// 焦点环往外 inflate 的距离。环画在 `foregroundPainter` 上，不占布局空间。
  final double ringOffset;

  @override
  List<Object?> get props => [hairline, thin, ring, ringOffset];

  static MuiBorders lerp(MuiBorders a, MuiBorders b, double t) => MuiBorders(
    hairline: lerpDouble(a.hairline, b.hairline, t)!,
    thin: lerpDouble(a.thin, b.thin, t)!,
    ring: lerpDouble(a.ring, b.ring, t)!,
    ringOffset: lerpDouble(a.ringOffset, b.ringOffset, t)!,
  );
}

/// 投影档。深色档接近全零 —— 灰度暗档的阴影肉眼不可见，分层靠描边。
@immutable
class MuiElevations with MuiValue {
  const MuiElevations({
    this.none = const [],
    required this.low,
    required this.high,
  });

  factory MuiElevations.of(Brightness brightness) {
    final dark = brightness == .dark;
    return MuiElevations(
      low: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: dark ? 0.0 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      high: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: dark ? 0.42 : 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  final List<BoxShadow> none;
  final List<BoxShadow> low;
  final List<BoxShadow> high;

  @override
  List<Object?> get props => [none, low, high];

  static MuiElevations lerp(MuiElevations a, MuiElevations b, double t) =>
      MuiElevations(
        none: BoxShadow.lerpList(a.none, b.none, t)!,
        low: BoxShadow.lerpList(a.low, b.low, t)!,
        high: BoxShadow.lerpList(a.high, b.high, t)!,
      );
}

/// 交互状态的统一透明度旋钮。禁用态走透明度不走变形，是全仓既定 DNA。
@immutable
class MuiStateTokens with MuiValue {
  const MuiStateTokens({
    this.disabledOpacity = 0.38,
    this.disabledContainerOpacity = 0.12,
    this.hoverOpacity = 0.08,
    this.pressedOpacity = 0.12,
    this.focusOpacity = 0.10,
    this.dragOpacity = 0.16,
  });

  final double disabledOpacity;
  final double disabledContainerOpacity;
  final double hoverOpacity;
  final double pressedOpacity;
  final double focusOpacity;
  final double dragOpacity;

  @override
  List<Object?> get props => [
    disabledOpacity,
    disabledContainerOpacity,
    hoverOpacity,
    pressedOpacity,
    focusOpacity,
    dragOpacity,
  ];

  static MuiStateTokens lerp(MuiStateTokens a, MuiStateTokens b, double t) =>
      MuiStateTokens(
        disabledOpacity: lerpDouble(a.disabledOpacity, b.disabledOpacity, t)!,
        disabledContainerOpacity: lerpDouble(
          a.disabledContainerOpacity,
          b.disabledContainerOpacity,
          t,
        )!,
        hoverOpacity: lerpDouble(a.hoverOpacity, b.hoverOpacity, t)!,
        pressedOpacity: lerpDouble(a.pressedOpacity, b.pressedOpacity, t)!,
        focusOpacity: lerpDouble(a.focusOpacity, b.focusOpacity, t)!,
        dragOpacity: lerpDouble(a.dragOpacity, b.dragOpacity, t)!,
      );
}

/// 图标默认尺寸与颜色。lucide 的统一入口。
@immutable
class MuiIconThemeData with MuiValue {
  const MuiIconThemeData({
    required this.color,
    this.size = 20,
    this.smallSize = 18,
    this.largeSize = 24,
  });

  final Color color;
  final double size;
  final double smallSize;
  final double largeSize;

  @override
  List<Object?> get props => [color, size, smallSize, largeSize];

  static MuiIconThemeData lerp(
    MuiIconThemeData a,
    MuiIconThemeData b,
    double t,
  ) => MuiIconThemeData(
    color: Color.lerp(a.color, b.color, t)!,
    size: lerpDouble(a.size, b.size, t)!,
    smallSize: lerpDouble(a.smallSize, b.smallSize, t)!,
    largeSize: lerpDouble(a.largeSize, b.largeSize, t)!,
  );
}
