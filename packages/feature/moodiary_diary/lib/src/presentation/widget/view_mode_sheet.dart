import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class ViewModeSheet extends StatefulWidget {
  const ViewModeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return MSheet.show<void>(context, builder: (_) => const ViewModeSheet());
  }

  static bool get _showModes => ViewModeType.values.length > 1;

  @override
  State<ViewModeSheet> createState() => _ViewModeSheetState();
}

class _ViewModeSheetState extends State<ViewModeSheet> {
  late int _mode =
      MoodiaryKVs.homeViewMode.get() ?? ViewModeType.timeline.number;
  late int _sort = MoodiaryKVs.homeSortMode.get() ?? DiarySort.timeDesc.number;

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

  void _apply() {
    MoodiaryKVs.homeViewMode.set(_mode);
    MoodiaryKVs.homeSortMode.set(_sort);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showModes = ViewModeSheet._showModes;
    return MSheetScaffold<void>(
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
