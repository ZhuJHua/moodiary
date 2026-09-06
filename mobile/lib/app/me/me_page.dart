import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> with RouteAware {
  DateTime? _selectedDay;

  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) moodiaryRouteObserver.subscribe(this, route);

    final visible = Visibility.of(context);
    if (_wasVisible == false && visible) _refresh();
    _wasVisible = visible;
  }

  @override
  void dispose() {
    moodiaryRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  void _refresh() =>
      ref.read(dashboardControllerProvider.notifier).refreshIfStale();

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.meTitle)),
      body: ListView(
        padding: .fromLTRB(
          12,
          4,
          12,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _HeatmapCard(
            stats: stats,
            selected: _selectedDay,
            onSelect: (day) =>
                setState(() => _selectedDay = day == _selectedDay ? null : day),
          ),
          const SizedBox(height: 12),
          _StatRow(stats: stats),
          const SizedBox(height: 16),
          _SectionLabel(context.l10n.app.meSectionRecall),
          const _RecallGrid(),
          const SizedBox(height: 16),
          _SectionLabel(context.l10n.app.meSectionManage),
          _ManageRows(
            categoryCount: stats?.categoryCount,
            placeCount: ref.watch(placeControllerProvider).value?.length,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(6, 0, 6, 8),
      child: Text(
        text,
        style: context.theme.typography.labelMedium.emphasized.onSurfaceVariant,
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final DashboardStats? stats;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  const _HeatmapCard({
    required this.stats,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final l10n = context.l10n;
    final data = stats;

    return Card.filled(
      color: colors.surfaceContainerLow,
      margin: .zero,
      child: Padding(
        padding: const .all(14),
        child: data == null || data.diaryCount == 0
            ? SizedBox(
                height: 96,
                child: Center(
                  child: Text(
                    data == null ? '' : l10n.app.meHeatmapEmpty,
                    style: typo.bodyMedium.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: .stretch,
                children: [
                  _Header(stats: data),
                  const SizedBox(height: 14),
                  MHeatmap(
                    endDate: _today(),
                    levels: {
                      for (final e in data.byDay.entries) e.key: e.value.level,
                    },
                    selected: selected,
                    onDaySelected: onSelect,
                    monthLabel: TimeFormat.monthAbbr,
                    semanticsLabel: l10n.app.meHeatmapSemantics,
                  ),
                  const SizedBox(height: 12),
                  _Footer(stats: data, selected: selected),
                ],
              ),
      ),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _Header extends StatelessWidget {
  final DashboardStats stats;

  const _Header({required this.stats});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    final colors = context.theme.colors;
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                crossAxisAlignment: .baseline,
                textBaseline: .alphabetic,
                children: [
                  Text(
                    '${stats.lastYearCount}',
                    style: typo.headlineSmall.emphasized.onSurface.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.app.meYearLabel,
                    style: typo.bodyMedium.onSurfaceVariant,
                  ),
                ],
              ),
              Text(
                l10n.app.meThisMonth(count: stats.thisMonthCount),
                style: typo.labelMedium.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (stats.streakDays > 0)
          Container(
            padding: const .fromLTRB(8, 4, 10, 4),
            decoration: ShapeDecoration(
              color: colors.secondaryContainer,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  LucideIcons.flame,
                  size: 14,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.app.meStreak(count: stats.streakDays),
                  style: typo.labelMedium.emphasized.onSecondaryContainer
                      .copyWith(fontFeatures: const [.tabularFigures()]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final DashboardStats stats;
  final DateTime? selected;

  const _Footer({required this.stats, required this.selected});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    final l10n = context.l10n;
    final day = selected;
    final writing = day == null ? null : stats.byDay[day];

    final String detail;
    if (day == null) {
      detail = l10n.app.meHeatmapHint;
    } else if (writing == null) {
      detail = '${TimeFormat.monthDay(day)} · ${l10n.app.meDayNothing}';
    } else {
      detail =
          '${TimeFormat.monthDay(day)} · '
          '${l10n.diary.timelineMonthCount(count: writing.count)} · '
          '${l10n.diary.wordCount(count: writing.words)}';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            detail,
            maxLines: 1,
            overflow: .ellipsis,
            style: day == null
                ? typo.labelMedium.outline
                : typo.labelMedium.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        MHeatmapLegend(
          lessLabel: l10n.app.meLegendLess,
          moreLabel: l10n.app.meLegendMore,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final DashboardStats? stats;

  const _StatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card.filled(
      color: context.theme.colors.surfaceContainerLow,
      margin: .zero,
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            _Metric(label: l10n.app.dashUseDays, value: stats?.useDays),
            _Metric(label: l10n.app.dashWordCount, value: stats?.wordCount),
            _Metric(
              label: l10n.app.dashCategoryCount,
              value: stats?.categoryCount,
            ),
            _Metric(label: l10n.app.dashTagCount, value: stats?.tagCount),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int? value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    return Expanded(
      child: Column(
        mainAxisSize: .min,
        children: [
          AnimatedText(
            value == null ? '' : '${value!}',
            style: typo.titleMedium.emphasized.onSurface.copyWith(
              fontFeatures: const [.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          AdaptiveText(label, style: typo.labelSmall.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _RecallGrid extends StatelessWidget {
  const _RecallGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RecallTile(
                icon: LucideIcons.image,
                label: l10n.media.title,
                onTap: () => const MediaRoute().push(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RecallTile(
                icon: LucideIcons.map,
                label: l10n.app.mapTitle,
                onTap: () => const MapRoute().push(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RecallTile(
                icon: LucideIcons.waypoints,
                label: l10n.diary.knowledgeGraph,
                onTap: () => const DiaryGraphRoute().push(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RecallTile(
                icon: LucideIcons.calendarDays,
                label: l10n.app.meCalendar,
                onTap: () => const CalendarRoute().push(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecallTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _RecallTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final enabled = onTap != null;
    final fg = enabled ? colors.onSurface : colors.outline;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: const .all(.circular(18)),
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(14),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? colors.onSurfaceVariant : colors.outline,
              ),
              const SizedBox(height: 20),
              Text(label, style: typo.bodyMedium.onSurface.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageRows extends StatelessWidget {
  final int? categoryCount;
  final int? placeCount;

  const _ManageRows({required this.categoryCount, required this.placeCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final l10n = context.l10n;
    Widget chevron() =>
        Icon(LucideIcons.chevronRight, color: colors.onSurfaceVariant);
    Widget lead(IconData i) => Icon(i, color: colors.onSurfaceVariant);
    Widget countChevron(int? count) => count == null
        ? chevron()
        : Row(
            mainAxisSize: .min,
            children: [
              Text('$count', style: context.theme.typography.bodySmall.primary),
              const SizedBox(width: 4),
              chevron(),
            ],
          );

    return Card.filled(
      color: colors.surfaceContainerLow,
      margin: .zero,
      child: Column(
        children: [
          SettingListTile(
            isFirst: true,
            title: l10n.app.categoryManager,
            leading: lead(LucideIcons.folders),
            trailing: countChevron(categoryCount),
            onTap: () => const CategoryManagerRoute().push(context),
          ),
          SettingListTile(
            title: l10n.app.placeManager,
            leading: lead(LucideIcons.mapPinned),
            trailing: countChevron(placeCount),
            onTap: () => const PlaceManagerRoute().push(context),
          ),
          SettingListTile(
            title: l10n.app.recycle,
            leading: lead(LucideIcons.trash),
            trailing: chevron(),
            onTap: () => const RecycleRoute().push(context),
          ),
          SettingListTile(
            title: l10n.export.pageTitle,
            leading: lead(LucideIcons.fileOutput),
            trailing: chevron(),
            onTap: () => const ExportRoute().push(context),
          ),
          SettingListTile(
            isLast: true,
            title: l10n.app.syncBackup,
            leading: lead(LucideIcons.refreshCw),
            trailing: chevron(),
            onTap: () => const BackupSyncRoute().push(context),
          ),
        ],
      ),
    );
  }
}
