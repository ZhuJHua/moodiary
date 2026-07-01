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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
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
            ValueListenableBuilder<int>(
              valueListenable: MoodiaryKVs.homeViewMode.getNotifier(),
              builder: (context, mode, _) {
                final current = ViewModeType.getType(mode);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final type in ViewModeType.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: type == ViewModeType.values.last ? 0 : 12,
                          ),
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
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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
    Widget row() => Expanded(
      child: Row(
        children: [
          Expanded(child: _cell(block)),
          const SizedBox(width: 8),
          Expanded(child: _cell(block)),
        ],
      ),
    );
    return Column(
      children: [row(), const SizedBox(height: 8), row()],
    );
  }

  Widget _calendar(Color block) {
    const filled = {2, 3, 9, 14, 15, 20, 27, 31};
    return GridView.count(
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      children: [
        for (var i = 0; i < 35; i++)
          _cell(
            filled.contains(i) ? block : block.withValues(alpha: 0.22),
            radius: 2,
          ),
      ],
    );
  }
}
