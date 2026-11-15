import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_diary/src/application/word_cloud_controller.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 自定义时间范围：像「日历」的年视图那样按年翻页、点月份定范围，
/// 另有「最早一篇 / 最新一篇」这类边界快捷操作，以及精确到日的两个入口。
///
/// 只负责选范围，返回选中的 (start, end)（本地时间，end 是闭区间的那一天）。
class WordCloudRangePage extends ConsumerStatefulWidget {
  const WordCloudRangePage({super.key, this.initialStart, this.initialEnd});

  /// 路由入口：起止是 ISO8601 字符串（`params` 只放标量）。
  factory WordCloudRangePage.fromRoute(GoRouterState state) =>
      WordCloudRangePage(
        initialStart: _parseDate(state.params['start']),
        initialEnd: _parseDate(state.params['end']),
      );

  final DateTime? initialStart;
  final DateTime? initialEnd;

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  ConsumerState<WordCloudRangePage> createState() => _WordCloudRangePageState();
}

/// 选择器返回的结果（end 是闭区间的那一天）。
typedef WordCloudRangeResult = ({DateTime start, DateTime end});

class _WordCloudRangePageState extends ConsumerState<WordCloudRangePage> {
  static const int _anchorYear = 6000;

  late DateTime? _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;
  late final int _anchor = widget.initialEnd?.year ?? DateTime.now().year;
  late final PageController _pager = PageController(
    initialPage: _pageForYear(_anchor),
  );

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  int _pageForYear(int year) => _anchorYear + year - _anchor;

  int _yearForPage(int page) => _anchor + page - _anchorYear;

  /// 点月份：没选完就从这个月起一段；选完了就重新开始（点更早的月会交换端点）。
  void _tapMonth(DateTime month) {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    setState(() {
      if (_start == null || _end != null) {
        _start = from;
        _end = null;
        return;
      }
      if (!from.isAfter(_start!)) {
        _end = _start;
        _start = to;
        return;
      }
      _end = to;
    });
  }

  void _setBoundary({DateTime? start, DateTime? end}) => setState(() {
    if (start != null) _start = DateTime(start.year, start.month, start.day);
    if (end != null) _end = DateTime(end.year, end.month, end.day);
  });

  bool _inRange(DateTime month) {
    final from = _start;
    final to = _end ?? _start;
    if (from == null || to == null) return false;
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return !last.isBefore(from) && !first.isAfter(to);
  }

  bool _rangeComplete() => _start != null && _end != null;

  Future<void> _pickDay({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _start ?? now,
      firstDate: DateTime(2015),
      lastDate: now,
      switchToInputEntryModeIcon: const Icon(LucideIcons.keyboard),
      switchToCalendarEntryModeIcon: const Icon(LucideIcons.calendarDays),
    );
    if (picked == null) return;
    _setBoundary(start: isStart ? picked : null, end: isStart ? null : picked);
  }

  void _apply() {
    final from = _start;
    final to = _end ?? _start;
    if (from == null || to == null) return;
    Navigator.of(context)
        .pop((start: from, end: to.isBefore(from) ? from : to));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wordCloudTimeIndexProvider);
    final l10n = context.l10n;
    final theme = context.theme;
    final index = async.value;
    final first = index?.first;
    final last = index?.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wordcloud.rangePageTitle),
        actions: [
          TextButton(
            onPressed: _start == null ? null : _apply,
            child: Text(l10n.wordcloud.rangeApply),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Text(
                  _summary(l10n),
                  style: theme.typography.titleSmall.onSurface,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 边界快捷：把起点/终点直接推到语料的两端
                    ActionChip(
                      avatar: const Icon(
                        LucideIcons.arrowRightToLine,
                        size: 16,
                      ),
                      label: Text(l10n.wordcloud.rangeFromEarliest),
                      onPressed: first == null
                          ? null
                          : () => _setBoundary(start: first),
                    ),
                    ActionChip(
                      avatar: const Icon(LucideIcons.arrowLeftToLine, size: 16),
                      label: Text(l10n.wordcloud.rangeToLatest),
                      onPressed: last == null
                          ? null
                          : () => _setBoundary(end: last),
                    ),
                    ActionChip(
                      avatar: const Icon(LucideIcons.calendarRange, size: 16),
                      label: Text(l10n.wordcloud.rangeEverything),
                      onPressed: first == null || last == null
                          ? null
                          : () => _setBoundary(start: first, end: last),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDay(isStart: true),
                        icon: const Icon(LucideIcons.play, size: 16),
                        label: Text(
                          _start == null
                              ? l10n.wordcloud.rangePickStart
                              : TimeFormat.anchorDate(_start!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDay(isStart: false),
                        icon: const Icon(LucideIcons.flag, size: 16),
                        label: Text(
                          _end == null
                              ? l10n.wordcloud.rangePickEnd
                              : TimeFormat.anchorDate(_end!),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_rangeComplete())
                  Padding(
                    padding: const .only(top: 6),
                    child: Text(
                      l10n.wordcloud.rangeHint,
                      style: theme.typography.labelSmall.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pager,
              itemBuilder: (context, page) {
                final year = _yearForPage(page);
                return _YearMonths(
                  year: year,
                  byMonth: index?.byMonth,
                  isSelected: _inRange,
                  onTapMonth: _tapMonth,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _summary(Translations l10n) {
    final from = _start;
    final to = _end;
    if (from == null) return l10n.wordcloud.rangeHint;
    final start = TimeFormat.longDate(from);
    if (to == null) return l10n.wordcloud.rangePickedStart(day: start);
    return '$start – ${TimeFormat.longDate(to)}';
  }
}

/// 一年：12 个月份卡（像日历的年视图，但没有日期格子）。
class _YearMonths extends StatelessWidget {
  final int year;
  final Map<DateTime, int>? byMonth;
  final bool Function(DateTime month) isSelected;
  final ValueChanged<DateTime> onTapMonth;

  const _YearMonths({
    required this.year,
    required this.byMonth,
    required this.isSelected,
    required this.onTapMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      children: [
        Text('$year', style: theme.typography.titleMedium.emphasized.onSurface),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            padding: const .fromLTRB(16, 0, 16, 16),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (var month = 1; month <= 12; month++)
                _MonthCard(
                  month: DateTime(year, month),
                  count: byMonth?[DateTime(year, month)] ?? 0,
                  selected: isSelected(DateTime(year, month)),
                  onTap: () => onTapMonth(DateTime(year, month)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DateTime month;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _MonthCard({
    required this.month,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: const .all(.circular(14)),
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(10),
          child: Column(
            crossAxisAlignment: .start,
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                TimeFormat.monthAbbr(month),
                style: theme.typography.titleSmall.emphasized.onSurface
                    .copyWith(
                      color: selected
                          ? colors.onSecondaryContainer
                          : colors.onSurface,
                    ),
              ),
              if (count > 0)
                Text(
                  context.l10n.wordcloud.monthCount(count: count),
                  style: theme.typography.labelSmall.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
