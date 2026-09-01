import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
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

/// 锚页。前面还剩 6000 个月（500 年）可以往回翻，往后不设界。
const int _kAnchorPage = 6000;

/// 格子里的字号上限。格子是定死的 46×54，日期与篇数跟着系统字号涨到 1.6× 就会互相顶。
/// 与 `MHeatmap` / `MNavBar` 同一个理由：网格是图表不是正文。下半屏的日记列表不受此限。
const double _kCellMaxTextScale = 1.15;

/// 格子顶部那一行（日期 + 篇数）的定高。钉死它，各种格子的版式才一致。
const double _kHeaderHeight = 18;

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

/// 页码 ↔ 月份。[anchorMonth] 落在 [_kAnchorPage] 这一页上。
///
/// 月份加减一律交给 [DateTime] 自己归一（`month + n` 越界会自动进位到年），
/// **别手写 `~/ 12` 与 `% 12`** —— 负数月份的取模在 Dart 里不是数学取模，跨到锚点之前
/// 的年份会差一整年。
@visibleForTesting
DateTime monthForPage(DateTime anchorMonth, int page) =>
    DateTime(anchorMonth.year, anchorMonth.month + page - _kAnchorPage);

@visibleForTesting
int pageForMonth(DateTime anchorMonth, DateTime month) =>
    _kAnchorPage +
    (month.year - anchorMonth.year) * 12 +
    (month.month - anchorMonth.month);

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

  /// 翻月的锚：`_kAnchorPage` 这一页恒等于**打开这一页时的当月**。往前能翻 500 年，
  /// 往后无限 —— [PageView.builder] 不给 itemCount 就没有后界。
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

  /// 翻到某一页。**只动页面，不动选中日** —— 选中日等落位之后由
  /// [_onSettled] 改，见那里的说明。
  void _goToPage(int page) {
    _pageCtl.animateToPage(
      page,
      duration: Durations.medium4,
      curve: Easing.emphasizedDecelerate,
    );
  }

  /// 月份滑到哪一页了。只更新标题 —— 它是个标签，跟着手指走才不会和网格错开。
  void _onPageChanged(int page) {
    setState(() => _month = _monthForPage(page));
  }

  /// **落位之后**才换选中日。滑动途中就改的话，手指还在拖、下半屏的日记已经换了一茬，
  /// 而且中途路过的月份都会各触发一次取数。
  void _onSettled() {
    final target = _pendingToday ? _today() : _pickDayIn(_month);
    _pendingToday = false;
    if (target == _selected) return;
    setState(() => _selected = target);
  }

  /// 「回到今天」按下之后那一次落位要选中今天，而不是按常规规则挑一天。
  bool _pendingToday = false;

  void _backToToday() {
    _pendingToday = true;
    _goToPage(_pageForMonth(_monthOf(_today())));
    // 已经在当月时不会有滚动，也就等不到落位回调。
    if (_pageCtl.hasClients &&
        _pageCtl.page?.round() == _pageForMonth(_month)) {
      _onSettled();
    }
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

/// 横向翻月。
///
/// [PageView] 要一个定高，拿不到 `shrinkWrap` 那套 —— 好在网格是**恒定六行**，
/// 高度由宽度算得出来：格宽 =（可用宽 − 6 个间隙）/ 7，格高 = 格宽 / [_kCellAspect]。
///
/// 两个回调分工是这一块的关键：[onPageChanged] 只改标题（它是个标签，得跟着手指走，
/// 不然网格滑过去了标题还写着上个月）；真正的动作 —— 换选中日、重新取当天的日记 ——
/// 等 [ScrollEndNotification] 落位之后再做。滑动途中就做的话，手指还在拖、下半屏已经
/// 换了一茬，而且一次快滑路过的每个月都会各触发一次取数。
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
            // depth 0 = 分页器自己。格子里那个 GridView 关掉了滚动，但布局时照样会
            // 冒泡通知上来，不筛掉的话每次重建都会被当成一次落位。
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
          // 高度由 [_MonthPager] 给死，这里只管铺格子。
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

/// 格子顶部那一行：左边日期、右边篇数。
///
/// **必须是 Row，不能是两个 Align。** 格子只有 `(360−16−18)/7 ≈ 46.6` 宽，两个绝对定位
/// 的角标在 320dp 上就贴到一起了，字号放大档更是直接叠上。Row + [Spacer] 让重叠在结构上
/// 不可能发生，挤不下时日期自己省略。
///
/// 「今天」= 日期用 `primary` 色 + 加粗，**不加任何形状**：46 宽的格子里，药丸或描边
/// 既挤又吵。封面格只加粗不上色，见下面的说明。
///
/// 整行定高 [_kHeaderHeight]，各种格子版式一致。
class _CellHeader extends StatelessWidget {
  final DateTime day;

  /// 0 = 那天没写。>1 才显示篇数。
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
    // 盖在封面上时前景走 onMedia —— 封面是任意画面，主题的 on* 角色在这里不成立。
    const tabular = [FontFeature.tabularFigures()];
    // 常规档：篇数、以及不是今天的日期。
    final style =
        (onCover
                ? typo.labelSmall.onMedia
                : count == 0
                ? typo.labelSmall.outline
                : typo.labelSmall.onSurfaceVariant)
            .copyWith(fontFeatures: tabular);

    // 今天 = primary + 粗。**封面上只加粗、不上色**：那儿的日期走 onMedia（恒定白），
    // 换成 primary 在灰度档就是纯黑压在深色 scrim 上、直接消失，有彩档也比周围那些白
    // 日期更暗，读起来像被禁用而不是「当前」。
    //
    // 加粗必须走 `.emphasized`，不能 `copyWith(fontWeight:)` —— 可变字体下 fontWeight
    // 会被 fontVariations 吃掉，不报错也不生效。
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
    // 照片上直接放字读不出来。顶部一条渐变 scrim 同时托住日期和篇数，
    // 比两个各自带底的小药丸干净。
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

/// 有封面：整格铺图，顶部一条 scrim 托住日期与篇数。
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

/// 没有封面：分类色条 + 标题首行。**别退回只剩一个日期数字** —— 那样无图的日子全都
/// 长一样，格子就没有任何可回忆的抓手，等于把日历退回成日期选择器。
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
