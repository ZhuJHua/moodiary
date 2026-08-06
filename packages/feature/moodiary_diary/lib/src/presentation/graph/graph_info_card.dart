import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

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
        ? TimeFormat.longDate(node.time)
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
      // 毛玻璃卡（无阴影）：浮在图上但不压图。走全仓统一的玻璃面，跟着设置里的
      // 「玻璃效果」开关走 —— 关掉后退成实色，而不是变成一层看不清字的半透明。
      child: Semantics(
        button: true,
        label: l10n.graphOpenDiary,
        child: MoodiaryGlassSurface(
          shape: const RoundedRectangleBorder(
            borderRadius: AppBorderRadius.xLargeBorderRadius,
          ),
          // 这张卡不投影（浮在图上但不压图），边界全靠发丝线交代。描边比默认再淡一档：
          // 图谱画布本身线条就多，实色描边会跟着一起抢。
          shadows: const [],
          borderColor: cs.outlineVariant.withValues(alpha: 0.45),
          child: Material(
            type: MaterialType.transparency,
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
                                  TimeFormat.longDate(node.time),
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
                                  icon: LucideIcons.arrowUpRight,
                                  count: outgoing,
                                ),
                              ],
                              if (incoming > 0) ...[
                                const SizedBox(width: 6),
                                _LinkChip(
                                  color: cs.tertiary,
                                  icon: LucideIcons.arrowDownLeft,
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
                          LucideIcons.crosshair,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: onCenter,
                      ),
                    Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant),
                    if (onClose != null)
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(LucideIcons.x, color: cs.onSurfaceVariant),
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
