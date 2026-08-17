import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 「我的」：统计 + 换个维度看日记 + 内容管理，设置在右上角。
///
/// 它是 app 层的组合面 —— 一页要同时碰 diary / media / sync / export 四个 feature 的
/// 路由，放进任何一个 feature 包都会变成 feature 互相 import。
class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> with RouteAware {
  DateTime? _selectedDay;

  /// null = 还没跑过 [didChangeDependencies]。见下面为什么首帧要跳过。
  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 「管理」那一组（回收站 / 分类管理 / 导出 / 同步）就在本页，从那儿恢复一篇日记
    // 或删掉一个分类后是 **pop 回来**、不换 tab，切 tab 那条路够不着。
    // 本页所在的是根壳那条 `/` 路由，pop 回它时 didPopNext 会响。
    final route = ModalRoute.of(context);
    if (route is PageRoute) moodiaryRouteObserver.subscribe(this, route);

    // 换 tab 走这条：IndexedStack 给每个 child 挂了 `_VisibilityScope`，
    // `Visibility.of` 读它并登记依赖，所以本页自己就能知道何时重新可见 ——
    // 不必让根壳知道这一页里有个看板、再反过来回调它。
    final visible = Visibility.of(context);
    // 首帧不推：build 里的 watch 自己就会算一趟，这里再推等于算两遍，而且此刻
    // provider 还没被 watch，read 会把它建起来又立刻回收。
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

  /// 没脏就是空操作 —— 所以站在别的 tab 上 pop 回来也不会白算一遍。
  void _refresh() =>
      ref.read(dashboardControllerProvider.notifier).refreshIfStale();

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardControllerProvider).value;
    return Scaffold(
      // 顶栏不放 ⚙：设置是本 tab 的主动作，落在底栏胶囊右边那颗按钮上
      // （见 root_shell 的 _navAction），三个 tab 各对应一个主动作。
      appBar: AppBar(title: Text(context.l10n.app.meTitle)),
      // 根壳开了 extendBody，底栏整条带高已折进 padding.bottom，直接读来让开。
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
          _ManageRows(categoryCount: stats?.categoryCount),
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

// ── 热力图卡 ──────────────────────────────────────────────────────────

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
            // 全新用户的 371 格全空，是一片灰点阵，看着像加载失败 —— 一行字比一张空网格
            // 诚实。数据还没回来时也走这里，不闪骨架。
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

// ── 数字栏 ────────────────────────────────────────────────────────────

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

// ── 回顾 ──────────────────────────────────────────────────────────────

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
              // TODO(calendar): 日历视图还没有页面。做的时候直接用
              // DashboardStats.byDay —— 月网格要的就是同一份日粒度聚合，
              // 补一个 CalendarRoute + 月历页即可，这里把 onTap 接上就行。
              child: _RecallTile(
                icon: LucideIcons.calendarDays,
                label: l10n.app.meCalendar,
                subtitle: l10n.app.meCalendarPending,
                onTap: null,
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
  final String? subtitle;
  final VoidCallback? onTap;

  const _RecallTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
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
              if (subtitle != null)
                Text(subtitle!, style: typo.labelSmall.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 管理 ──────────────────────────────────────────────────────────────

class _ManageRows extends StatelessWidget {
  final int? categoryCount;

  const _ManageRows({required this.categoryCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final l10n = context.l10n;
    Widget chevron() =>
        Icon(LucideIcons.chevronRight, color: colors.onSurfaceVariant);
    Widget lead(IconData i) => Icon(i, color: colors.onSurfaceVariant);

    return Card.filled(
      color: colors.surfaceContainerLow,
      margin: .zero,
      child: Column(
        children: [
          SettingListTile(
            isFirst: true,
            title: l10n.app.categoryManager,
            leading: lead(LucideIcons.folders),
            trailing: categoryCount == null
                ? chevron()
                : Row(
                    mainAxisSize: .min,
                    children: [
                      Text(
                        '$categoryCount',
                        style: context.theme.typography.bodySmall.primary,
                      ),
                      const SizedBox(width: 4),
                      chevron(),
                    ],
                  ),
            onTap: () => const CategoryManagerRoute().push(context),
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
