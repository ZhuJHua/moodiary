import 'package:mui/mui.dart';

enum MCalloutLevel { info, success, warning, error }

class MCallout extends StatelessWidget {
  const MCallout({
    super.key,
    required this.message,
    this.level = .info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  }) : assert((actionLabel == null) == (onAction == null));

  final String message;
  final MCalloutLevel level;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final accent = switch (level) {
      .info => colors.harmonize(theme.info),
      .success => theme.success,
      .warning => theme.warning,
      .error => colors.error,
    };
    final background = Color.alphaBlend(
      accent.withValues(alpha: theme.isDark ? 0.14 : 0.08),
      colors.surface,
    );
    final typography = theme.typography;
    final body = Text(message, style: typography.bodyMedium.onSurfaceVariant);
    Widget content = Row(
      crossAxisAlignment: .start,
      spacing: 12,
      children: [
        Padding(
          padding: const .only(top: 1),
          child: Icon(
            icon ??
                switch (level) {
                  .info => LucideIcons.info,
                  .success => LucideIcons.circleCheck,
                  .warning => LucideIcons.triangleAlert,
                  .error => LucideIcons.circleAlert,
                },
            size: 20,
            color: accent,
          ),
        ),
        Expanded(
          child: title == null
              ? body
              : Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(
                      title!,
                      style: typography.titleSmall.emphasized.onSurface,
                    ),
                    body,
                  ],
                ),
        ),
      ],
    );
    if (onAction != null) {
      content = Row(
        spacing: 12,
        children: [
          Expanded(child: content),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: accent,
              minimumSize: const Size(0, 36),
              padding: const .symmetric(horizontal: 12),
              tapTargetSize: .shrinkWrap,
            ),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      );
    }
    if (onDismiss != null) {
      content = Row(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          Expanded(child: content),
          Transform.translate(
            offset: const Offset(0, -6),
            child: IconButton(
              tooltip: context.muiL10n.close,
              iconSize: 18,
              visualDensity: .compact,
              color: colors.onSurfaceVariant,
              onPressed: onDismiss,
              icon: const Icon(LucideIcons.x),
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: .circular(theme.radii.lg),
      ),
      child: Padding(
        padding: .fromLTRB(16, 12, onDismiss == null ? 16 : 8, 12),
        child: content,
      ),
    );
  }
}
