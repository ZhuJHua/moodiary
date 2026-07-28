import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 选中节点的悬浮信息卡（总图与 ego 图共用）。整卡可点打开日记；前导圆点用**节点本色**，
/// 与画布上看到的颜色一致。出/入链分开显示——只给合计看不出方向。
class GraphInfoCard extends StatelessWidget {
  final DiaryGraphNode node;
  final Color accent;
  final int outgoing;
  final int incoming;
  final VoidCallback onOpen;
  final VoidCallback? onCenter;

  /// 为空则不显示关闭按钮（ego 图默认展示中心节点，没有「取消选中」可言）。
  final VoidCallback? onClose;

  const GraphInfoCard({
    super.key,
    required this.node,
    required this.accent,
    required this.outgoing,
    required this.incoming,
    required this.onOpen,
    this.onClose,
    this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final title = node.title.trim().isEmpty
        ? TimeUtil.longDate(node.time)
        : node.title.trim();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      // 毛玻璃卡（无阴影）：半透明底 + 背景模糊 + 发丝线描边，浮在图上但不压图。
      child: Semantics(
        button: true,
        label: l10n.graphOpenDiary,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 4, 11),
                  child: Row(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    TimeUtil.longDate(node.time),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (outgoing > 0) ...[
                                  const SizedBox(width: 8),
                                  _LinkChip(
                                    color: cs.primary,
                                    icon: Icons.north_east_rounded,
                                    count: outgoing,
                                  ),
                                ],
                                if (incoming > 0) ...[
                                  const SizedBox(width: 6),
                                  _LinkChip(
                                    color: cs.tertiary,
                                    icon: Icons.south_west_rounded,
                                    count: incoming,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (onCenter != null)
                        IconButton(
                          tooltip: l10n.graphSetAsCenter,
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.center_focus_strong_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: onCenter,
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      if (onClose != null)
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: onClose,
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int count;

  const _LinkChip({
    required this.color,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
