import 'package:mui/mui.dart';

enum MButtonSize {
  small,

  medium,

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
      visualDensity: VisualDensity.standard,
    );
  }
}
