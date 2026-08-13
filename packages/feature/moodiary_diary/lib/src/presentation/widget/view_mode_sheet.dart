import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 首页的视图与排序。选择先暂存，按下确定才落盘 —— 「取消」必须真的能取消
/// （对齐同批改造的轮询间隔 / 并发数）。
class ViewModeSheet extends StatefulWidget {
  const ViewModeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return MSheet.show<void>(context, builder: (_) => const ViewModeSheet());
  }

  /// 只剩一种模式时不画模式切换——一格的选择器没有意义。加回第二种布局时自动出现。
  static bool get _showModes => ViewModeType.values.length > 1;

  @override
  State<ViewModeSheet> createState() => _ViewModeSheetState();
}

class _ViewModeSheetState extends State<ViewModeSheet> {
  late int _mode =
      MoodiaryKVs.homeViewMode.get() ?? ViewModeType.timeline.number;
  late int _sort = MoodiaryKVs.homeSortMode.get() ?? DiarySort.timeDesc.number;

  /// 时间线是按记录时间叙事的轴，只给两种时间序；「最近修改在前」留给信息流。
  static const List<DiarySort> _timelineSorts = [.timeDesc, .timeAsc];

  List<DiarySort> get _availableSorts =>
      ViewModeType.getType(_mode) == .timeline
      ? _timelineSorts
      : DiarySort.values;

  String _label(BuildContext context, ViewModeType type) => switch (type) {
    .timeline => context.l10n.diary.viewModeTimeline,
    .feed => context.l10n.diary.viewModeFeed,
  };

  String _sortLabel(BuildContext context, DiarySort sort) => switch (sort) {
    .timeDesc => context.l10n.diary.sortNewestFirst,
    .timeAsc => context.l10n.diary.sortOldestFirst,
    .lastModifiedDesc => context.l10n.diary.sortModifiedFirst,
  };

  IconData _sortIcon(DiarySort sort) => switch (sort) {
    .timeDesc => LucideIcons.arrowDown,
    .timeAsc => LucideIcons.arrowUp,
    .lastModifiedDesc => LucideIcons.calendarClock,
  };

  /// 停在当前模式选不到的排序上就退回默认的「最新在前」。两处都要做：切模式时，
  /// 以及打开面板时 —— 老用户的 KV 里可能存着「时间线 + 最近修改在前」这种旧组合，
  /// 不归一的话面板里一项都不高亮，按确定还会把它原样存回去。
  void _coerceSort() {
    if (!_availableSorts.any((sort) => sort.number == _sort)) {
      _sort = DiarySort.timeDesc.number;
    }
  }

  @override
  void initState() {
    super.initState();
    _coerceSort();
  }

  void _pickMode(ViewModeType type) {
    setState(() {
      _mode = type.number;
      _coerceSort();
    });
  }

  Future<void> _apply() async {
    await MoodiaryKVs.homeViewMode.set(_mode);
    await MoodiaryKVs.homeSortMode.set(_sort);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showModes = ViewModeSheet._showModes;
    return MSheetScaffold<void>(
      // 标题跟着内容走：只有排序时就别再叫「视图模式」。
      title: showModes ? l10n.diary.pageViewModeButton : l10n.diary.sortTitle,
      icon: LucideIcons.arrowDownUp,
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(label: l10n.common.ok, isPrimary: true, onPressed: _apply),
      ],
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (showModes) ...[
            SegmentedButton<ViewModeType>(
              showSelectedIcon: false,
              selected: {.getType(_mode)},
              segments: [
                for (final type in ViewModeType.values)
                  ButtonSegment(
                    value: type,
                    label: Text(_label(context, type)),
                  ),
              ],
              onSelectionChanged: (value) => _pickMode(value.first),
            ),
            const SizedBox(height: 20),
            MFormSection(l10n.diary.sortTitle),
            const SizedBox(height: 10),
          ],
          for (final sort in _availableSorts)
            MSheetOptionTile<int>(
              option: MSheetOption(
                value: sort.number,
                label: _sortLabel(context, sort),
                icon: _sortIcon(sort),
              ),
              selected: _sort == sort.number,
              onTap: () => setState(() => _sort = sort.number),
            ),
        ],
      ),
    );
  }
}
