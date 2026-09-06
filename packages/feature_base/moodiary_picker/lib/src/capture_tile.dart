import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

class CaptureTile extends StatelessWidget {
  const CaptureTile({super.key, required this.video, required this.onTap});

  final bool video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return MInkWell(
      onTap: onTap,
      child: ColoredBox(
        color: theme.colors.surfaceContainerHigh,
        child: Column(
          mainAxisAlignment: .center,
          spacing: 6,
          children: [
            Icon(
              video ? LucideIcons.video : LucideIcons.camera,
              size: 22,
              color: theme.colors.onSurfaceVariant,
            ),
            Text(
              video ? l10n.picker.record : l10n.picker.capture,
              style: theme.typography.labelSmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
