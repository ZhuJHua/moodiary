import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class GraphInfoCard extends StatelessWidget {
  final DiaryGraphNode node;
  final Color accent;
  final int outgoing;
  final int incoming;
  final VoidCallback onOpen;
  final VoidCallback? onCenter;

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
    final theme = context.theme;
    final cs = theme.colors;
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
      child: Semantics(
        button: true,
        label: l10n.diary.graphOpenDiary,
        child: MGlassSurface(
          shape: const RoundedRectangleBorder(
            borderRadius: AppBorderRadius.xLargeBorderRadius,
          ),
          shadows: const [],
          borderColor: cs.outlineVariant.withValues(alpha: 0.45),
          child: MInkWell(
            onTap: onOpen,
            child: Padding(
              padding: const .fromLTRB(14, 11, 4, 11),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(color: accent, shape: .circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style:
                              theme.typography.titleSmall.emphasized.onSurface,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                TimeFormat.longDate(node.time),
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: theme
                                    .typography
                                    .labelSmall
                                    .onSurfaceVariant,
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
                      tooltip: l10n.diary.graphSetAsCenter,
                      iconSize: 20,
                      visualDensity: .compact,
                      icon: Icon(
                        LucideIcons.crosshair,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: onCenter,
                    ),
                  Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant),
                  if (onClose != null)
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      iconSize: 20,
                      visualDensity: .compact,
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
    final theme = context.theme;
    return Container(
      padding: const .symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainerHighest,
        borderRadius: .circular(9),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text('$count', style: theme.typography.labelSmall.onSurfaceVariant),
        ],
      ),
    );
  }
}
