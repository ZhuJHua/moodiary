import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;

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

  /// 只剩一种模式时不画模式网格——一格的选择器没有意义。加回第二种布局时自动出现。
  static bool get _showModes => ViewModeType.values.length > 1;

  String _label(BuildContext context, ViewModeType type) => switch (type) {
    ViewModeType.timeline => context.l10n.diaryViewModeTimeline,
    ViewModeType.feed => context.l10n.diaryViewModeFeed,
  };

  String _sortLabel(BuildContext context, DiarySort sort) => switch (sort) {
    DiarySort.timeDesc => context.l10n.diarySortNewestFirst,
    DiarySort.timeAsc => context.l10n.diarySortOldestFirst,
    DiarySort.lastModifiedDesc => context.l10n.diarySortModifiedFirst,
  };

  IconData _sortIcon(DiarySort sort) => switch (sort) {
    DiarySort.timeDesc => LucideIcons.arrowDown,
    DiarySort.timeAsc => LucideIcons.arrowUp,
    DiarySort.lastModifiedDesc => LucideIcons.calendarClock,
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
                if (_showModes) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      context.l10n.diaryPageViewModeButton,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  // 间距与内边距按四格排布收紧，否则每格的预览会挤成条。
                  Row(
                    crossAxisAlignment: .start,
                    spacing: 8,
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
                ],
                _buildSortSection(context),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 时间线三种排序都成立：分组键跟着排序键走（见 `timelineStampOf`），
  /// 不再像日历那样需要把排序整段禁用。
  Widget _buildSortSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.diarySortTitle, style: context.textTheme.titleMedium),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
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
          padding: const EdgeInsets.all(9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _ViewModePreview(type: type, selected: selected),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                // 四列下「日历视图 / Calendar view」放不进一行，给第二行而不是省略号。
                maxLines: 2,
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
      ViewModeType.timeline => _timeline(block),
      ViewModeType.feed => _feed(block),
    };
  }

  Widget _cell(Color color, {double radius = 4}) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  /// 左文右图的条目堆叠——与真实版式同构：一条带图、一条纯文字。
  Widget _feed(Color block) {
    Widget row({required bool thumb, required int lines}) => Expanded(
      flex: thumb ? 5 : 3,
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(height: 5, child: _cell(block, radius: 2)),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 3,
                    child: _cell(block.withValues(alpha: 0.3), radius: 2),
                  ),
                ],
              ],
            ),
          ),
          if (thumb) ...[
            const SizedBox(width: 5),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: _cell(block.withValues(alpha: 0.55), radius: 3),
            ),
          ],
        ],
      ),
    );
    return Column(
      children: [
        row(thumb: true, lines: 2),
        const SizedBox(height: 7),
        row(thumb: false, lines: 1),
        const SizedBox(height: 7),
        row(thumb: true, lines: 2),
      ],
    );
  }

  /// 一条竖轴 + 三个节点，右侧是长短不一的条目——与真实版式同构。
  Widget _timeline(Color block) {
    Widget node(double barFlex, {bool dim = false}) => Expanded(
      flex: (barFlex * 10).round(),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: 8,
            child: Column(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: dim ? block.withValues(alpha: 0.35) : block,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: block.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(height: 6, child: _cell(block, radius: 3)),
                const SizedBox(height: 4),
                Expanded(child: _cell(block.withValues(alpha: 0.3), radius: 3)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(children: [node(1.4), node(0.8, dim: true), node(1.2)]);
  }
}
