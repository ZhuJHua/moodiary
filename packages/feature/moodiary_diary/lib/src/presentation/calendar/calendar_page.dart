import 'package:fast_image/fast_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

const double _kCellAspect = 46 / 54;
const double _kCellGap = 3;
const double _kGridPadding = 8;

// 恒定六行：行数跟着月份变的话，翻月时下半屏会上下弹
const int _kGridRows = 6;

// 锚页：往前 6000 个月（500 年），往后不设界
const int _kAnchorPage = 6000;

// 系统字号放大到 1.6× 时日期与篇数会互相顶，故封顶
const double _kCellMaxTextScale = 1.15;

const double _kHeaderHeight = 18;

@visibleForTesting
({int leading, int days}) monthGeometry(DateTime month) => (
  // weekday 是周一=1..周日=7，% 7 折成周日=0
  leading: DateTime(month.year, month.month).weekday % 7,
  // 下个月第 0 天 = 本月最后一天，跨年/闰年由 DateTime 自动归一
  days: DateTime(month.year, month.month + 1, 0).day,
);

// 别手写 ~/12 与 %12：负数月份取模在 Dart 不是数学取模，跨到锚点之前的年份会差一年
@visibleForTesting
DateTime monthForPage(DateTime anchorMonth, int page) =>
    DateTime(anchorMonth.year, anchorMonth.month + page - _kAnchorPage);

@visibleForTesting
int pageForMonth(DateTime anchorMonth, DateTime month) =>
    _kAnchorPage +
    (month.year - anchorMonth.year) * 12 +
    (month.month - anchorMonth.month);

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _month = _monthOf(_today());
  late DateTime _selected = _today();

  Future<List<Diary>>? _dayEntries;
  String _dayKey = '';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  late final DateTime _anchorMonth = _monthOf(_today());
  late final PageController _pageCtl = PageController(
    initialPage: _kAnchorPage,
  );

  DateTime _monthForPage(int page) => monthForPage(_anchorMonth, page);

  int _pageForMonth(DateTime month) => pageForMonth(_anchorMonth, month);

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageCtl.animateToPage(
      page,
      duration: Durations.medium4,
      curve: Easing.emphasizedDecelerate,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _month = _monthForPage(page));
  }

  void _onSettled() {
    final target = _pendingToday ? _today() : _pickDayIn(_month);
    _pendingToday = false;
    if (target == _selected) return;
    setState(() => _selected = target);
  }

  bool _pendingToday = false;

  void _backToToday() {
    _pendingToday = true;
    _goToPage(_pageForMonth(_monthOf(_today())));
    if (_pageCtl.hasClients &&
        _pageCtl.page?.round() == _pageForMonth(_month)) {
      _onSettled();
    }
  }

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
        : Future.wait(ids.map(getIt<DiaryRepository>().getDiaryByBusinessId))
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
            onPrev: () => _goToPage(_pageForMonth(_month) - 1),
            onNext: () => _goToPage(_pageForMonth(_month) + 1),
          ),
          const _WeekdayHeader(),
          _MonthPager(
            controller: _pageCtl,
            byDay: byDay,
            selected: _selected,
            today: _today(),
            monthForPage: _monthForPage,
            onPageChanged: _onPageChanged,
            onSettled: _onSettled,
            onSelect: (d) => setState(() => _selected = d),
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

class _MonthPager extends StatelessWidget {
  final PageController controller;
  final Map<DateTime, DayWriting>? byDay;
  final DateTime selected;
  final DateTime today;
  final DateTime Function(int page) monthForPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onSettled;
  final ValueChanged<DateTime> onSelect;

  const _MonthPager({
    required this.controller,
    required this.byDay,
    required this.selected,
    required this.today,
    required this.monthForPage,
    required this.onPageChanged,
    required this.onSettled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - _kGridPadding * 2 - _kCellGap * 6) / 7;
        final height =
            cell / _kCellAspect * _kGridRows + _kCellGap * (_kGridRows - 1) + 8;

        return SizedBox(
          height: height,
          child: NotificationListener<ScrollEndNotification>(
            // depth 0 = 分页器自身；子级冒泡通知不筛掉会被误判为落位
            onNotification: (n) {
              if (n.depth == 0) onSettled();
              return false;
            },
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemBuilder: (context, page) => _MonthGrid(
                month: monthForPage(page),
                byDay: byDay,
                selected: selected,
                today: today,
                onSelect: onSelect,
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: _kCellMaxTextScale,
        child: GridView.count(
          crossAxisCount: 7,
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
            for (var i = leading + days; i < _kGridRows * 7; i++)
              const SizedBox.shrink(),
          ],
        ),
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
      content = Padding(
        padding: const .fromLTRB(4, 3, 4, 3),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            _CellHeader(day: day, count: 0, onCover: false, isToday: isToday),
          ],
        ),
      );
    } else if (w.coverName != null) {
      content = _CoverCell(writing: w, day: day, isToday: isToday);
    } else {
      content = _TextCell(writing: w, day: day, isToday: isToday);
    }

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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: isSelected
            ? Border.all(color: colors.onSurface, width: 2)
            : null,
      ),
      child: MInkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class _CellHeader extends StatelessWidget {
  final DateTime day;

  // count 0 = 没写；只有 >1 才显示
  final int count;
  final bool onCover;
  final bool isToday;

  const _CellHeader({
    required this.day,
    required this.count,
    required this.onCover,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    const tabular = [FontFeature.tabularFigures()];
    final style =
        (onCover
                ? typo.labelSmall.onMedia
                : count == 0
                ? typo.labelSmall.outline
                : typo.labelSmall.onSurfaceVariant)
            .copyWith(fontFeatures: tabular);

    // 加粗须用 .emphasized，不能 copyWith(fontWeight)：可变字体下会被 fontVariations 吃掉，不报错也不生效
    final dateStyle = !isToday
        ? style
        : (onCover
                  ? typo.labelSmall.emphasized.onMedia
                  : typo.labelSmall.emphasized.primary)
              .copyWith(fontFeatures: tabular);

    final row = SizedBox(
      height: _kHeaderHeight,
      child: Row(
        children: [
          Flexible(child: Text('${day.day}', maxLines: 1, style: dateStyle)),
          const Spacer(),
          if (count > 1) Text('$count', style: style),
        ],
      ),
    );

    if (!onCover) return row;
    return Container(
      padding: const .fromLTRB(4, 2, 4, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [
            context.theme.colors.scrim.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
      child: row,
    );
  }
}

class _CoverCell extends StatelessWidget {
  final DayWriting writing;
  final DateTime day;
  final bool isToday;

  const _CoverCell({
    required this.writing,
    required this.day,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final path = AppFiles.getRealPath(
      writing.coverIsVideo ? 'thumbnail' : 'image',
      writing.coverName!,
    );
    final cacheWidth = (48 * MediaQuery.devicePixelRatioOf(context)).round();

    return Stack(
      fit: .expand,
      children: [
        ColoredBox(color: colors.surfaceContainerHigh),
        Image(
          image: FastImage(path, tier: .s, decodeWidth: cacheWidth),
          fit: .cover,
          filterQuality: .low,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) =>
              _TextCell(writing: writing, day: day, isToday: isToday),
        ),
        Align(
          alignment: .topCenter,
          child: _CellHeader(
            day: day,
            count: writing.count,
            onCover: true,
            isToday: isToday,
          ),
        ),
      ],
    );
  }
}

class _TextCell extends StatelessWidget {
  final DayWriting writing;
  final DateTime day;
  final bool isToday;

  const _TextCell({
    required this.writing,
    required this.day,
    required this.isToday,
  });

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
            _CellHeader(
              day: day,
              count: writing.count,
              onCover: false,
              isToday: isToday,
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
          onTap: () => DiaryRoute(diaryId: diary.id).push(context),
          child: Padding(
            padding: const .all(10),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                if (cover != null) ...[
                  ClipRRect(
                    borderRadius: .circular(9),
                    child: Image(
                      image: FastImage(
                        AppFiles.getRealPath('image', cover),
                        tier: .s,
                        decodeWidth:
                            (44 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                      ),
                      width: 44,
                      height: 44,
                      fit: .cover,
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
