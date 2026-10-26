import 'package:mui/mui.dart';

class MNoticeItem extends StatelessWidget {
  const MNoticeItem({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      crossAxisAlignment: .start,
      spacing: 12,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colors.surfaceContainerHigh,
            borderRadius: .circular(theme.radii.md),
          ),
          child: Icon(icon, size: 20, color: theme.colors.onSurfaceVariant),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              Text(title, style: theme.typography.titleSmall.onSurface),
              if (body != null)
                Text(
                  body!,
                  style: theme.typography.bodyMedium.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
