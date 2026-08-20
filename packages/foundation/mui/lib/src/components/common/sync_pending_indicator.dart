import 'package:mui/mui.dart';

/// 同步进行中的聚合提示卡。不为每篇远端日记插入独立占位 —— manifest 只有 LWW 时间戳，
/// 占位卡无法按真实展示时间排序、会出现在错误位置；待更新的已有日记改用 [SyncPendingBadge]。
class SyncPendingSummaryCard extends StatelessWidget {
  final int newCount;

  final int updateCount;

  /// 文案由调用方给：mui 是零业务依赖的设计系统包，取不到 App 的文案，
  /// 也不该把「同步」这类领域词收进自己那几个通用词里。
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

/// 本地有改动、尚未上行同步的「待同步」角标。与 [SyncPendingBadge]（pull 侧「同步中」）
/// 同形不同色以区分；同一卡片上「同步中」优先。
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
