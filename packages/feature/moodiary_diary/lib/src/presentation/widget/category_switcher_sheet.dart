import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

class CategorySelection {
  final String? categoryId;

  const CategorySelection(this.categoryId);
}

class CategorySwitcherSheet extends ConsumerStatefulWidget {
  final String? selectedId;

  const CategorySwitcherSheet({super.key, this.selectedId});

  static Future<CategorySelection?> show(
    BuildContext context, {
    String? selectedId,
  }) {
    return showModalBottomSheet<CategorySelection>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CategorySwitcherSheet(selectedId: selectedId),
    );
  }

  @override
  ConsumerState<CategorySwitcherSheet> createState() =>
      _CategorySwitcherSheetState();
}

class _CategorySwitcherSheetState extends ConsumerState<CategorySwitcherSheet> {
  String _query = '';

  void _select(String? categoryId) {
    Navigator.of(context).pop(CategorySelection(categoryId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderedCategoriesProvider);
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.72),
        child: async.buildLoading(
          data: (categories) {
            final q = _query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? categories
                : categories
                      .where((c) => c.categoryName.toLowerCase().contains(q))
                      .toList();
            return ValueListenableBuilder(
              valueListenable: SyncPendingTracker.instance.listenable,
              builder: (context, pending, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: Row(
                        children: [
                          Text(
                            context.l10n.editCategory,
                            style: context.textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            context.l10n.categorySwitcherCount(
                              categories.length,
                            ),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (categories.length >= 8)
                      _SearchField(
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        children: [
                          if (q.isEmpty)
                            _SheetRow(
                              icon: Icons.notes_rounded,
                              label: context.l10n.categoryAllDiary,
                              count: counts?.total,
                              selected: widget.selectedId == null,
                              onTap: () => _select(null),
                            ),
                          if (filtered.isEmpty && q.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  context.l10n.categoryNoMatch,
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          for (final c in filtered)
                            _SheetRow(
                              color: categoryColorOf(
                                colorValue: c.color,
                                id: c.id,
                              ),
                              label: c.categoryName,
                              count: counts?.byCategory[c.id] ?? 0,
                              selected: widget.selectedId == c.id,
                              syncing: pending.updateCategoryIds.contains(c.id),
                              onTap: () => _select(c.id),
                            ),
                          if (q.isEmpty)
                            for (
                              var i = 0;
                              i < pending.newCategoryIds.length;
                              i++
                            )
                              const _PendingRow(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12 + media.padding.bottom,
                      ),
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            const CategoryManagerRoute().push(context),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(context.l10n.categoryManageEntry),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorderRadius,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.l10n.categorySearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final Color? color;
  final IconData? icon;
  final String label;
  final int? count;
  final bool selected;
  final bool syncing;
  final VoidCallback onTap;

  const _SheetRow({
    this.color,
    this.icon,
    required this.label,
    required this.count,
    required this.selected,
    this.syncing = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color fg;
    if (!selected) {
      bg = Colors.transparent;
      fg = scheme.onSurface;
    } else if (color == null) {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    } else {
      bg = Color.alphaBlend(
        color!.withValues(alpha: dark ? 0.30 : 0.16),
        scheme.surfaceContainerHigh,
      );
      fg = Color.lerp(color, dark ? Colors.white : Colors.black, 0.35)!;
    }

    final blockColor = color ?? scheme.surfaceContainerHighest;
    final onBlock = color == null
        ? scheme.onSurfaceVariant
        : (blockColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon ?? Icons.label_rounded,
                  size: 19,
                  color: onBlock,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (syncing)
                const SyncPendingBadge()
              else if (selected)
                Icon(Icons.check_rounded, size: 20, color: fg)
              else if (count != null)
                Text(
                  '$count',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.label_outline_rounded,
              size: 19,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.categorySyncingPlaceholder,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ],
      ),
    );
  }
}
