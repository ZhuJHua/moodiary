import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

const int _kSearchThreshold = 8;

const int _kTopTags = 8;

class CategoryDrawer extends ConsumerStatefulWidget {
  const CategoryDrawer({super.key});

  @override
  ConsumerState<CategoryDrawer> createState() => _CategoryDrawerState();
}

class _CategoryDrawerState extends ConsumerState<CategoryDrawer> {
  String _query = '';

  void _pick(DiaryFilter filter) {
    // 跨筛选存活的选中 id 会让 softDeleteByIds 匹配不上，删除变成静默空操作
    ref.read(diarySelectionProvider.notifier).clear();
    ref.read(homeDiaryFilterProvider.notifier).select(filter);
    Navigator.of(context).pop();
  }

  void _open(MoodiaryRouteBase route) {
    Navigator.of(context).pop();
    route.push(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final filter = ref.watch(homeDiaryFilterProvider);
    final categoryState = ref.watch(orderedCategoriesProvider);
    final categoryList = categoryState.value;
    final categories = categoryList ?? const [];
    final countState = ref.watch(categoryDiaryCountsProvider);
    final counts = countState.value;
    final total = counts?.total;
    final uncategorized = counts == null
        ? null
        : (counts.total -
                  counts.byCategory.values.fold<int>(0, (a, b) => a + b))
              .clamp(0, counts.total);

    final query = _query.trim().toLowerCase();
    final tagState = ref.watch(tagCatalogProvider);
    final catalog = tagState.value;
    final usage = catalog?.usage ?? const <TagUsage>[];
    final usedCount = usage.where((tag) => tag.count > 0).length;
    final visibleTags = [
      for (final (index, tag) in usage.indexed)
        if ((tag.count > 0 || tag.name == filter.tagName) &&
            (query.isEmpty
                ? index < _kTopTags || tag.name == filter.tagName
                : tag.name.toLowerCase().contains(query)))
          tag,
    ];
    final more = usedCount - visibleTags.where((tag) => tag.count > 0).length;
    final visibleCategories = query.isEmpty
        ? categories
        : categories
              .where((c) => c.categoryName.toLowerCase().contains(query))
              .toList();
    final uncategorizedLabel = context.l10n.diary.categoryNoCategory;
    final showUncategorized = query.isEmpty
        ? filter.uncategorized ||
              (categories.isNotEmpty && (uncategorized ?? 0) > 0)
        : uncategorizedLabel.toLowerCase().contains(query);

    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: getIt<SyncPendingTracker>().listenable,
          builder: (context, pending, _) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                if (_query.isNotEmpty ||
                    categories.length >= _kSearchThreshold ||
                    usedCount > _kTopTags)
                  Padding(
                    padding: const .fromLTRB(12, 0, 12, 8),
                    child: SearchBar(
                      hintText: context.l10n.diary.drawerSearchHint,
                      leading: const Icon(LucideIcons.search, size: 20),
                      constraints: const BoxConstraints(minHeight: 42),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        colors.surfaceContainerHigh,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: .only(
                      bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      if (query.isEmpty) ...[
                        _Tile(
                          label: context.l10n.diary.categoryAllDiary,
                          count: total,
                          selected: filter.isAll,
                          height: 48,
                          leading: const Icon(LucideIcons.bookOpen, size: 18),
                          onTap: () => _pick(const .all()),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 28,
                          endIndent: 28,
                          color: colors.outlineVariant,
                        ),
                      ],
                      _SectionHeader(
                        label: context.l10n.common.category,
                        tooltip: context.l10n.diary.categoryManageEntry,
                        onManage: () => _open(const CategoryManagerRoute()),
                      ),
                      for (final c in visibleCategories)
                        _Tile(
                          label: c.categoryName,
                          count: counts?.byCategory[c.id],
                          selected: filter.categoryId == c.id,
                          color: categoryColorOf(colorValue: c.color, id: c.id),
                          syncing: pending.updateCategoryIds.contains(c.id),
                          onTap: () => _pick(.category(c.id)),
                        ),
                      if (query.isEmpty) ...[
                        for (var i = 0; i < pending.newCategoryIds.length; i++)
                          _PendingTile(
                            label:
                                context.l10n.diary.categorySyncingPlaceholder,
                          ),
                        if (categoryList?.isEmpty == true &&
                            pending.newCategoryIds.isEmpty)
                          _EmptyHint(
                            label: context.l10n.diary.drawerNoCategories,
                          ),
                      ],
                      if (showUncategorized)
                        _Tile(
                          label: uncategorizedLabel,
                          count: uncategorized,
                          selected: filter.uncategorized,
                          onTap: () => _pick(const .uncategorized()),
                        ),
                      _SectionHeader(
                        label: context.l10n.diary.tags,
                        tooltip: context.l10n.diary.tagManageEntry,
                        onManage: () => _open(const TagManagerRoute()),
                      ),
                      if (visibleTags.isNotEmpty)
                        Padding(
                          padding: const .symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in visibleTags)
                                MChip(
                                  label: '#${tag.name}',
                                  semanticLabel: '#${tag.name}, ${tag.count}',
                                  trailing: Text('${tag.count}'),
                                  selected: filter.tagName == tag.name,
                                  onTap: () => _pick(.tag(tag.name)),
                                ),
                              if (query.isEmpty && more > 0)
                                MChip(
                                  label: context.l10n.diary.drawerMoreTags(
                                    count: more,
                                  ),
                                  variant: .ghost,
                                  trailing: const Icon(
                                    LucideIcons.chevronRight,
                                    size: 16,
                                  ),
                                  onTap: () => _open(const TagManagerRoute()),
                                ),
                            ],
                          ),
                        ),
                      if (query.isEmpty && catalog?.usage.isEmpty == true)
                        _EmptyHint(label: context.l10n.diary.drawerNoTags),
                      if (query.isNotEmpty &&
                          categoryList != null &&
                          catalog != null &&
                          visibleCategories.isEmpty &&
                          visibleTags.isEmpty &&
                          !showUncategorized)
                        Padding(
                          padding: const .symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            context.l10n.diary.drawerNoMatch,
                            style: context
                                .theme
                                .typography
                                .bodyMedium
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onManage;

  const _SectionHeader({
    required this.label,
    required this.tooltip,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16, 4, 16, 6),
    child: Row(
      children: [
        Text(label, style: context.theme.typography.labelMedium.outline),
        const Spacer(),
        SizedBox.square(
          dimension: 40,
          child: IconButton(
            tooltip: tooltip,
            icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
            onPressed: onManage,
          ),
        ),
      ],
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  final String label;

  const _EmptyHint({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(28, 0, 28, 8),
    child: Text(label, style: context.theme.typography.bodySmall.outline),
  );
}

class _Tile extends StatelessWidget {
  final String label;

  final int? count;
  final bool selected;
  final double height;
  final Widget? leading;
  final Color? color;
  final bool syncing;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.count,
    required this.selected,
    this.height = 44,
    this.leading,
    this.color,
    this.syncing = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return Padding(
      padding: const .symmetric(horizontal: 12),
      child: Semantics(
        selected: selected,
        child: MInkWell(
          borderRadius: MuiRadius.md,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Stack(
              alignment: .centerStart,
              children: [
                if (selected)
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color ?? colors.onSurface,
                      borderRadius: const .all(.circular(1.5)),
                    ),
                  ),
                Padding(
                  padding: const .symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: leading ?? Center(child: _Swatch(color: color)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: selected
                              ? typo.bodyLarge.emphasized.onSurface
                              : typo.bodyLarge.onSurfaceVariant,
                        ),
                      ),
                      if (syncing) ...[
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.cloudUpload,
                          size: 14,
                          color: colors.primary,
                        ),
                      ],
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style:
                              (selected
                                      ? typo.labelMedium.emphasized.onSurface
                                      : typo.labelMedium.outline)
                                  .copyWith(
                                    fontFeatures: const [.tabularFigures()],
                                  ),
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

class _PendingTile extends StatelessWidget {
  final String label;

  const _PendingTile({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Padding(
      padding: const .symmetric(horizontal: 26, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color? color;

  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: .circle,
        border: color == null ? .all(color: colors.outline, width: 1.4) : null,
      ),
    );
  }
}
