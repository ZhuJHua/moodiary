import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 同步进行中的聚合提示卡。不为每篇远端日记插入独立占位 —— manifest 只有 LWW 时间戳，
/// 占位卡无法按真实展示时间排序、会出现在错误位置；待更新的已有日记改用 [SyncPendingBadge]。
class SyncPendingSummaryCard extends StatelessWidget {
  final int newCount;

  final int updateCount;

  const SyncPendingSummaryCard({
    super.key,
    required this.newCount,
    required this.updateCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final parts = [
      if (newCount > 0) '$newCount 篇待下载',
      if (updateCount > 0) '$updateCount 篇待更新',
    ].join(' · ');
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                '云端同步中：$parts',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncPendingBadge extends StatelessWidget {
  const SyncPendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.refreshCw,
            size: 11,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            '同步中',
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// 本地有改动、尚未上行同步的「待同步」角标。与 [SyncPendingBadge]（pull 侧「同步中」）
/// 同形不同色以区分；同一卡片上「同步中」优先。
class SyncDirtyBadge extends StatelessWidget {
  const SyncDirtyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.cloudUpload,
            size: 11,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            '待同步',
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
