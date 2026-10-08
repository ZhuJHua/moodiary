import 'package:mui/mui.dart';

class MOverlayLabel extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const MOverlayLabel({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final radius = BorderRadius.circular(theme.radii.sm - 2);
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.overlay, borderRadius: radius),
      child: MInkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 8, vertical: 3),
          child: Text(
            label,
            style: theme.typography.labelSmall.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
