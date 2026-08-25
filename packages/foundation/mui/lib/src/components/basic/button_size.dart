import 'package:mui/mui.dart';

/// 按钮尺寸档。**圆角跟着尺寸走**，不是所有按钮共用主题里那一个 12 ——
/// M3 的形状阶梯本来就是按尺寸分的：12 放在 32 高的小按钮上圆得接近胶囊，
/// 放在 56 高的整宽按钮上又显方。
///
/// 只覆盖 `shape` / 高度 / 横向留白，配色与排版仍旧来自
/// `filledButtonTheme` 一类的子主题 —— [ButtonStyle] 是逐属性合并的，
/// 这里没给的属性照旧走主题。
///
/// ```dart
/// FilledButton(style: MButtonSize.small.style(context), …)
/// ```
enum MButtonSize {
  /// 32 高、圆角 [MuiRadii.sm]。密集处的次要动作：底栏确认、卡片内联动作。
  small,

  /// 40 高、圆角 [MuiRadii.md]。**默认档**，与主题值一致，不必显式传。
  medium,

  /// 56 高、圆角 [MuiRadii.lg]。整宽的主动作：引导页、空态。
  large;

  double get height => switch (this) {
    MButtonSize.small => 32,
    MButtonSize.medium => 40,
    MButtonSize.large => 56,
  };

  double get horizontalPadding => switch (this) {
    MButtonSize.small => 12,
    MButtonSize.medium => 16,
    MButtonSize.large => 24,
  };

  double radius(MuiRadii radii) => switch (this) {
    MButtonSize.small => radii.sm,
    MButtonSize.medium => radii.md,
    MButtonSize.large => radii.lg,
  };

  /// 命中区仍旧是 48（`tapTargetSize` 保持框架默认的 padded）：视觉高度可以小，
  /// 点得到与否不该跟着小。
  ButtonStyle style(BuildContext context) {
    final theme = context.theme;
    return ButtonStyle(
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius(theme.radii)),
        ),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      // 祖先若把 visualDensity 调紧过，这里得钉回来，否则实际高度会低于本档。
      visualDensity: VisualDensity.standard,
    );
  }
}
