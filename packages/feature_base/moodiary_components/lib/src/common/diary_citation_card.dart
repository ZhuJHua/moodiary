import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

enum DiaryCitationState { loading, ready, recycled, missing }

class DiaryCitationCard extends StatelessWidget {
  final DiaryCitationState state;
  final DateTime? time;
  final String title;
  final DiaryMood? mood;
  final String? weatherIcon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double? width;

  const DiaryCitationCard({
    super.key,
    required this.state,
    this.time,
    this.title = '',
    this.mood,
    this.weatherIcon,
    this.onTap,
    this.onRemove,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final muted = state != .ready;
    final accent = muted
        ? scheme.outlineVariant
        : mood?.color ?? scheme.primary;

    final Widget body = switch (state) {
      .loading => Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          _bar(scheme, 56),
          const SizedBox(height: 6),
          _bar(scheme, 96),
        ],
      ),
      .missing => Text(
        l10n.diary.linkNotFound,
        maxLines: 1,
        overflow: .ellipsis,
        style: typography.bodySmall.onSurfaceVariant,
      ),
      .recycled || .ready => Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Row(
            children: [
              if (time case final t?)
                Text(
                  TimeFormat.monthDay(t),
                  style: typography.labelSmall.onSurfaceVariant,
                ),
              if (state == .recycled) ...[
                const SizedBox(width: 6),
                Text(
                  l10n.diary.citationRecycled,
                  style: typography.labelSmall.onSurfaceVariant,
                ),
              ] else if (qweatherIcon(weatherIcon) case final icon?) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 12, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title.trim().isEmpty ? l10n.common.untitled : title.trim(),
            maxLines: 1,
            overflow: .ellipsis,
            style: muted
                ? typography.bodySmall.onSurfaceVariant
                : typography.bodySmall.onSurface,
          ),
        ],
      ),
    };

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: state == .ready ? onTap : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                ColoredBox(color: accent, child: const SizedBox(width: 3)),
                Expanded(
                  child: Padding(
                    padding: const .fromLTRB(10, 8, 10, 8),
                    child: body,
                  ),
                ),
                if (onRemove case final remove?)
                  MInkWell(
                    onTap: remove,
                    child: Padding(
                      padding: const .symmetric(horizontal: 10),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(ColorScheme scheme, double width) => Container(
    width: width,
    height: 10,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: MuiRadius.sm,
    ),
  );
}
