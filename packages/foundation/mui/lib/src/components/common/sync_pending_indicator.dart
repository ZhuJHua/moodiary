import 'package:mui/mui.dart';

class SyncPendingSummaryCard extends StatelessWidget {
  final int newCount;

  final int updateCount;

  final String Function(int newCount, int updateCount) label;

  const SyncPendingSummaryCard({
    super.key,
    required this.newCount,
    required this.updateCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: MuiRadius.md),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label(newCount, updateCount),
                style: context.theme.typography.bodyMedium.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncPendingBadge extends StatelessWidget {
  final String label;

  const SyncPendingBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: .circular(999),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.refreshCw,
            size: 11,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.theme.typography.labelSmall.onTertiaryContainer,
          ),
        ],
      ),
    );
  }
}

class SyncDirtyBadge extends StatelessWidget {
  final String label;

  const SyncDirtyBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: .circular(999),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.cloudUpload,
            size: 11,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.theme.typography.labelSmall.onSecondaryContainer,
          ),
        ],
      ),
    );
  }
}
