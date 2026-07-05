import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

class ViewModeSheet extends StatelessWidget {
  const ViewModeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => const ViewModeSheet(),
    );
  }

  String _label(BuildContext context, ViewModeType type) => switch (type) {
    ViewModeType.list => context.l10n.diaryViewModeList,
    ViewModeType.grid => context.l10n.diaryViewModeGrid,
    ViewModeType.calendar => context.l10n.diaryViewModeCalendar,
  };

  String _sortLabel(BuildContext context, DiarySort sort) => switch (sort) {
    DiarySort.timeDesc => context.l10n.diarySortNewestFirst,
    DiarySort.timeAsc => context.l10n.diarySortOldestFirst,
    DiarySort.lastModifiedDesc => context.l10n.diarySortModifiedFirst,
  };

  IconData _sortIcon(DiarySort sort) => switch (sort) {
    DiarySort.timeDesc => Icons.south_rounded,
    DiarySort.timeAsc => Icons.north_rounded,
    DiarySort.lastModifiedDesc => Icons.edit_calendar_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ValueListenableBuilder<int>(
          valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
          builder: (context, mode, _) {
            final current = ViewModeType.getType(mode);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    context.l10n.diaryPageViewModeButton,
                    style: context.textTheme.titleMedium,
                  ),
                ),
                Row(
                  crossAxisAlignment: .start,
                  spacing: 12,
                  children: [
                    for (final type in ViewModeType.values)
                      Expanded(
                        child: _ViewModeOption(
                          type: type,
                          label: _label(context, type),
                          selected: type == current,
                          onTap: () async {
                            await MoodiaryKVs.homeViewMode.set(type.number);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSortSection(
                  context,
                  disabled: current == ViewModeType.calendar,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortSection(BuildContext context, {required bool disabled}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.diarySortTitle,
              style: context.textTheme.titleMedium,
            ),
            if (disabled) ...[
              const SizedBox(width: 8),
              Text(
                context.l10n.diarySortCalendarHint,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        AnimatedOpacity(
          opacity: disabled ? 0.4 : 1,
          duration: Durations.short3,
          child: IgnorePointer(
            ignoring: disabled,
            child: ValueListenableBuilder<int>(
              valueListenable: MoodiaryKVs.homeSortMode.getNotifier(),
              builder: (context, sortMode, _) {
                return RadioGroup<int>(
                  groupValue: sortMode,
                  onChanged: (v) {
                    if (v != null) MoodiaryKVs.homeSortMode.set(v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final sort in DiarySort.values)
                        RadioListTile<int>(
                          value: sort.number,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(_sortLabel(context, sort)),
                          secondary: Icon(_sortIcon(sort), size: 20),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewModeOption extends StatelessWidget {
  final ViewModeType type;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewModeOption({
    required this.type,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _ViewModePreview(type: type, selected: selected),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModePreview extends StatelessWidget {
  final ViewModeType type;
  final bool selected;

  const _ViewModePreview({required this.type, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final block = selected ? scheme.primary : scheme.onSurfaceVariant;
    return switch (type) {
      ViewModeType.list => _list(block),
      ViewModeType.grid => _grid(block),
      ViewModeType.calendar => _calendar(block),
    };
  }

  Widget _cell(Color color, {double radius = 4}) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  Widget _list(Color block) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          SizedBox(height: 14, width: double.infinity, child: _cell(block)),
        ],
      ],
    );
  }

  Widget _grid(Color block) {
    Widget column(List<int> flexes) => Expanded(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (var i = 0; i < flexes.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Expanded(flex: flexes[i], child: _cell(block)),
          ],
        ],
      ),
    );
    return Row(
      crossAxisAlignment: .stretch,
      children: [
        column(const [3, 2]),
        const SizedBox(width: 8),
        column(const [2, 3]),
      ],
    );
  }

  Widget _calendar(Color block) {
    const filled = {2, 3, 9, 14, 15, 20, 27, 31};
    const rows = 5, cols = 7;
    return Center(
      child: AspectRatio(
        aspectRatio: cols / rows,
        child: Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: 3),
              Expanded(
                child: Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: 3),
                      Expanded(
                        child: _cell(
                          filled.contains(r * cols + c)
                              ? block
                              : block.withValues(alpha: 0.22),
                          radius: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
