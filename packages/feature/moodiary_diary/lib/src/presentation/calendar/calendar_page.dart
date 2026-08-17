import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 格子的宽高比。略高于正方形，缩略图才不至于被裁得只剩一条。
const double _kCellAspect = 46 / 54;
const double _kCellGap = 3;
const double _kGridPadding = 8;

/// 网格**恒定六行**。一个月按前导空格能占 4–6 行（2 月 1 号是周日时只要 4 行，
/// 8 月 1 号是周六时要 6 行），行数跟着月份变的话，翻月时整个下半屏会上下弹。
const int _kGridRows = 6;

/// 认定为一次翻月的横扫速度。
const double _kSwipeVelocity = 180;

/// 一个月的网格几何：前面空几格、这个月有几天。
///
/// 两处都别自己算：
/// * `DateTime.weekday` 是**周一 1 到周日 7**，`% 7` 才把周日折成 0（周日打头）；
/// * `DateTime(y, m + 1, 0)` 是「下个月第 0 天」= 本月最后一天，跨年（12 月 + 1）
///   与闰年二月都由 [DateTime] 自己归一，不需要任何分支。
@visibleForTesting
({int leading, int days}) monthGeometry(DateTime month) => (
  leading: DateTime(month.year, month.month).weekday % 7,
  days: DateTime(month.year, month.month + 1, 0).day,
);

/// 月历回顾：一屏一个月，格子里是**那天的封面图**，下半屏是选中日的日记。
///
/// 格子画的是「那天是什么」而不是「那天写没写」—— 后者「我的」页的热力图已经说了，
/// 而且说得更全（一整年）。日历要是也只画个点，它就是个更大更慢的热力图。
///
/// **翻月不查库。** 数据全部来自 [DashboardStats.byDay]（惰性重算，见
/// [DashboardController]）：isar_plus 的读查询不走二级索引，按月查一次就是全表扫一次，
/// 翻页翻不起。选中某天后才按 id 走主键 get 取出当天的日记，那个是 O(1)。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _month = _monthOf(_today());
  late DateTime _selected = _today();

  /// 当天日记的取数结果。按 [_dayKey] 记忆化 —— 直接在 build 里 new 一个 Future 的话，
  /// 每次重建都会重新取一遍，列表也会跟着闪。
  Future<List<Diary>>? _dayEntries;
  String _dayKey = '';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  /// 新月从哪一侧滑进来。+1 = 往后翻。
  int _slideDir = 1;

  void _shiftMonth(int delta) {
    final month = DateTime(_month.year, _month.month + delta);
    setState(() {
      _slideDir = delta;
      _month = month;
      _selected = _pickDayIn(month);
    });
  }

  void _backToToday() {
    final month = _monthOf(_today());
    setState(() {
      _slideDir = month.isBefore(_month) ? -1 : 1;
      _month = month;
      _selected = _today();
    });
  }

  /// 换月后选中日**必须落在当月**：否则网格里一个高亮都没有，下半屏却还挂着上个月
  /// 某天的日记，看起来像是没翻动。
  ///
  /// 优先保留同一个日号（翻月对比同一天是常见动作）；那天没写就退到当月第一个写过的
  /// 日子，好让下半屏有东西可看；整月都空才停在同号。
  DateTime _pickDayIn(DateTime month) {
    final byDay = ref.read(dashboardControllerProvider).value?.byDay;
    final days = monthGeometry(month).days;
    final sameDom = DateTime(
      month.year,
      month.month,
      _selected.day.clamp(1, days),
    );
    if (byDay == null || byDay.containsKey(sameDom)) return sameDom;
    for (var d = 1; d <= days; d++) {
      final day = DateTime(month.year, month.month, d);
      if (byDay.containsKey(day)) return day;
    }
    return sameDom;
  }

  void _syncDayEntries(DayWriting? writing) {
    final ids = writing?.ids ?? const <String>[];
    final key = '${TimeFormat.isoDate(_selected)}|${ids.join(',')}';
    if (key == _dayKey) return;
    _dayKey = key;
    _dayEntries = ids.isEmpty
        ? Future.value(const <Diary>[])
        : Future.wait(ids.map(DiaryRepository.get().getDiaryByBusinessId))
              .then((list) => list.whereType<Diary>().toList());
  }

  @override
  Widget build(BuildContext context) {
    final byDay = ref.watch(dashboardControllerProvider).value?.byDay;
    _syncDayEntries(byDay?[_selected]);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diary.calendarTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.diary.calendarBackToToday,
            icon: const Icon(LucideIcons.calendarCheck),
            onPressed: _backToToday,
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(
            month: _month,
            entryCount: _monthCount(byDay),
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const _WeekdayHeader(),
          // 横扫翻月。用 GestureDetector 而不是 PageView：网格是定高的，
          // PageView 还要维护无限页与两侧预建，为一个翻页动作不值当。
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < _kSwipeVelocity) return;
              _shiftMonth(v < 0 ? 1 : -1);
            },
            child: AnimatedSwitcher(
              duration: Durations.medium2,
              switchInCurve: Easing.emphasizedDecelerate,
              switchOutCurve: Easing.emphasizedAccelerate,
              transitionBuilder: (child, animation) {
                // 进场的从 _slideDir 那一侧来，退场的往反方向走。退场那个的 key
                // 已经不是当前月份了，据此分辨。
                final incoming = child.key == ValueKey(_month);
                final dx = (incoming ? _slideDir : -_slideDir) * 0.1;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(dx, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_month),
                child: _MonthGrid(
                  month: _month,
                  byDay: byDay,
                  selected: _selected,
                  today: _today(),
                  onSelect: (d) => setState(() => _selected = d),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _DayEntries(day: _selected, entries: _dayEntries),
          ),
        ],
      ),
    );
  }

  int? _monthCount(Map<DateTime, DayWriting>? byDay) {
    if (byDay == null) return null;
    var sum = 0;
    byDay.forEach((day, w) {
      if (day.year == _month.year && day.month == _month.month) sum += w.count;
    });
    return sum;
  }
}

// ── 顶部月份条 ────────────────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  final DateTime month;
  final int? entryCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthBar({
    required this.month,
    required this.entryCount,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const .fromLTRB(6, 0, 6, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: onPrev,
          ),
          Text(
            TimeFormat.monthTitle(month),
            style: theme.typography.titleMedium.emphasized.onSurface,
          ),
          const Spacer(),
          if (entryCount != null)
            Text(
              context.l10n.diary.timelineMonthCount(count: entryCount!),
              style: theme.typography.labelMedium.onSurfaceVariant,
            ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    // 取任意一周的七天来问 intl 要本地化的简称，周日打头。
    final sunday = DateTime(2026, 8, 2);
    return Padding(
      padding: const .symmetric(horizontal: _kGridPadding),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                TimeFormat.weekdayShort(sunday.add(Duration(days: i))),
                textAlign: .center,
                maxLines: 1,
                style: context.theme.typography.labelSmall.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 月网格 ────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, DayWriting>? byDay;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final (:leading, :days) = monthGeometry(month);

    return Padding(
      padding: const .symmetric(horizontal: _kGridPadding, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: _kCellGap,
        crossAxisSpacing: _kCellGap,
        childAspectRatio: _kCellAspect,
        children: [
          for (var i = 0; i < leading; i++) const SizedBox.shrink(),
          for (var d = 1; d <= days; d++)
            () {
              final day = DateTime(month.year, month.month, d);
              return _DayCell(
                day: day,
                writing: byDay?[day],
                isToday: day == today,
                isSelected: day == selected,
                onTap: () => onSelect(day),
              );
            }(),
          // 补满六行，见 [_kGridRows]。
          for (var i = leading + days; i < _kGridRows * 7; i++)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final DayWriting? writing;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.writing,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final radius = BorderRadius.circular(9);
    final w = writing;

    Widget content;
    if (w == null) {
      content = _DateBadge(day: day, onCover: false, muted: true);
    } else if (w.coverName != null) {
      content = _CoverCell(writing: w, day: day);
    } else {
      content = _TextCell(writing: w, day: day);
    }

    // 格子画的是图和数字，读屏拿不到任何东西 —— 日期与篇数只能显式给。
    // 子树里那些日期数字、标题节选会和这里的 label 打架，整个排除掉。
    return Semantics(
      button: true,
      selected: isSelected,
      label: [
        TimeFormat.monthDay(day),
        if (w == null)
          context.l10n.diary.calendarEmptyDay
        else
          context.l10n.diary.timelineMonthCount(count: w.count),
      ].join(' · '),
      child: ExcludeSemantics(child: _cell(context, content, colors, radius)),
    );
  }

  Widget _cell(
    BuildContext context,
    Widget content,
    ColorScheme colors,
    BorderRadius radius,
  ) {
    final w = writing;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: isSelected
            ? Border.all(color: colors.onSurface, width: 2)
            : null,
      ),
      child: MInkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Stack(
          fit: .expand,
          children: [
            content,
            // 今天：底部一条短横。选中态已经有描边，两者可以叠。
            if (isToday)
              Align(
                alignment: .bottomCenter,
                child: Container(
                  width: 12,
                  height: 2,
                  margin: const .only(bottom: 3),
                  decoration: BoxDecoration(
                    // 盖在封面上时前景不能用主题色 —— 封面是任意画面。
                    color: w?.coverName != null
                        ? context.theme.onMedia
                        : colors.primary,
                    borderRadius: .circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 有封面：整格铺图，日期压在左上角。
class _CoverCell extends StatelessWidget {
  final DayWriting writing;
  final DateTime day;

  const _CoverCell({required this.writing, required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final path = AppFiles.getRealPath(
      writing.coverIsVideo ? 'thumbnail' : 'image',
      writing.coverName!,
    );
    // 一屏 42 格，不降采样就是 42 张原图进内存。按格子实际像素解。
    final cacheWidth = (48 * MediaQuery.devicePixelRatioOf(context)).round();

    return Stack(
      fit: .expand,
      children: [
        // 解码完成前的底色。整页从灰底逐格闪成彩色很难看。
        ColoredBox(color: colors.surfaceContainerHigh),
        Image.file(
          File(path),
          fit: .cover,
          cacheWidth: cacheWidth,
          filterQuality: .low,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) =>
              _TextCell(writing: writing, day: day),
        ),
        _DateBadge(day: day, onCover: true, muted: false),
        if (writing.count > 1) _CountBadge(count: writing.count),
      ],
    );
  }
}

/// 没有封面：分类色条 + 标题首行。**别退回只剩一个日期数字** —— 那样无图的日子全都
/// 长一样，格子就没有任何可回忆的抓手，等于把日历退回成日期选择器。
class _TextCell extends StatelessWidget {
  final DayWriting writing;
  final DateTime day;

  const _TextCell({required this.writing, required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final categoryId = writing.categoryId;
    final title = writing.title.trim().isEmpty
        ? context.l10n.common.untitled
        : writing.title;

    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const .fromLTRB(4, 3, 4, 3),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                _DateBadge(day: day, onCover: false, muted: false),
                const Spacer(),
                if (writing.count > 1)
                  Text(
                    '${writing.count}',
                    style: context.theme.typography.labelSmall.onSurfaceVariant,
                  ),
              ],
            ),
            if (categoryId != null)
              Container(
                width: 12,
                height: 3,
                margin: const .only(top: 2, bottom: 2),
                decoration: BoxDecoration(
                  color: categoryColorOf(id: categoryId),
                  borderRadius: .circular(2),
                ),
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: .ellipsis,
                style: context.theme.typography.labelSmall.onSurfaceVariant
                    .copyWith(fontSize: 9, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime day;
  final bool onCover;
  final bool muted;

  const _DateBadge({
    required this.day,
    required this.onCover,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    // 盖在封面上时前景走 onMedia —— 封面是任意画面，主题的 on* 角色在这里不成立。
    final base = onCover
        ? typo.labelSmall.emphasized.onMedia
        : muted
        ? typo.labelSmall.outline
        : typo.labelSmall.onSurfaceVariant;
    final text = Text(
      '${day.day}',
      style: base.copyWith(fontFeatures: const [.tabularFigures()]),
    );

    if (!onCover) {
      if (!muted) return text;
      return Align(
        alignment: .topLeft,
        child: Padding(padding: const .fromLTRB(6, 4, 0, 0), child: text),
      );
    }
    return Align(
      alignment: .topLeft,
      child: Container(
        margin: const .all(3),
        padding: const .symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: colors.scrim.withValues(alpha: 0.4),
          borderRadius: .circular(4),
        ),
        child: text,
      ),
    );
  }
}

/// 一天多篇时右上角的篇数。与信息流的 `+N` 蒙版同一套：scrim 底 + onMedia 字。
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topRight,
      child: Container(
        margin: const .all(3),
        constraints: const BoxConstraints(minWidth: 15),
        height: 15,
        alignment: .center,
        padding: const .symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: context.theme.colors.scrim.withValues(alpha: 0.5),
          borderRadius: .circular(8),
        ),
        child: Text(
          '$count',
          style: context.theme.typography.labelSmall.emphasized.onMedia,
        ),
      ),
    );
  }
}

// ── 下半屏：选中日的日记 ──────────────────────────────────────────────

class _DayEntries extends StatelessWidget {
  final DateTime day;
  final Future<List<Diary>>? entries;

  const _DayEntries({required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final future = entries;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Text(
                TimeFormat.monthDay(day),
                style: theme.typography.titleSmall.emphasized.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<List<Diary>>(
                  future: future,
                  builder: (context, snapshot) {
                    final n = snapshot.data?.length;
                    if (n == null) return const SizedBox.shrink();
                    return Text(
                      n == 0
                          ? context.l10n.diary.calendarEmptyDay
                          : context.l10n.diary.timelineMonthCount(count: n),
                      style: theme.typography.labelMedium.onSurfaceVariant,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Diary>>(
            future: future,
            builder: (context, snapshot) {
              final list = snapshot.data;
              // 取数极快（主键 get），这一小段空窗按空渲染，不闪骨架。
              if (list == null || list.isEmpty) return const SizedBox.shrink();
              return ListView.builder(
                padding: .fromLTRB(
                  12,
                  0,
                  12,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _EntryTile(diary: list[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final Diary diary;

  const _EntryTile({required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final colors = theme.colors;
    final category = ref.watch(categoryByIdProvider(diary.categoryId));
    final cover = diary.imageName.firstOrNull;
    final title = diary.title.trim().isEmpty
        ? context.l10n.common.untitled
        : diary.title;

    return Padding(
      padding: const .only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: const .all(.circular(14)),
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: () =>
              DiaryRoute(type: diary.type, diaryId: diary.id).push(context),
          child: Padding(
            padding: const .all(10),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                if (cover != null) ...[
                  ClipRRect(
                    borderRadius: .circular(9),
                    child: Image.file(
                      File(AppFiles.getRealPath('image', cover)),
                      width: 44,
                      height: 44,
                      fit: .cover,
                      cacheWidth: (44 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      errorBuilder: (context, _, _) => SizedBox.square(
                        dimension: 44,
                        child: ColoredBox(color: colors.surfaceContainerHigh),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: theme.typography.bodyMedium.emphasized.onSurface,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (category != null) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: .circle,
                                color: categoryColorOf(
                                  colorValue: category.color,
                                  id: category.id,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              category.categoryName,
                              style:
                                  theme.typography.labelSmall.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            TimeFormat.clock(diary.time),
                            style: theme.typography.labelSmall.outline,
                          ),
                        ],
                      ),
                      if (diary.contentText.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          diary.contentText.trim(),
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: theme.typography.bodySmall.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
