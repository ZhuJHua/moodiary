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
    final categoryList = ref.watch(orderedCategoriesProvider).value;
    final categories = categoryList ?? const [];
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    final total = counts?.total;
    final uncategorized = counts == null
        ? null
        : (counts.total -
                  counts.byCategory.values.fold<int>(0, (a, b) => a + b))
              .clamp(0, counts.total);

    final query = _query.trim().toLowerCase();
    final catalog = ref.watch(tagCatalogProvider).value;
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
    final visible = query.isEmpty
        ? categories
        : categories
              .where((c) => c.categoryName.toLowerCase().contains(query))
              .toList();

    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: getIt<SyncPendingTracker>().listenable,
          builder: (context, pending, _) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                _Header(total: total),
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
                    padding: const .only(bottom: 8),
                    children: [
                      if (query.isEmpty)
                        _Tile(
                          label: context.l10n.diary.categoryAllDiary,
                          count: total,
                          selected: filter.isAll,
                          leading: _Swatch.all(scheme: colors),
                          onTap: () => _pick(const .all()),
                        ),
                      _SectionHeader(
                        label: context.l10n.common.category,
                        count: categoryList?.length,
                        tooltip: context.l10n.diary.categoryManageEntry,
                        onManage: () => _open(const CategoryManagerRoute()),
                      ),
                      for (final c in visible)
                        _Tile(
                          label: c.categoryName,
                          count: counts?.byCategory[c.id],
                          selected: filter.categoryId == c.id,
                          leading: _Swatch(
                            color: categoryColorOf(
                              colorValue: c.color,
                              id: c.id,
                            ),
                          ),
                          syncing: pending.updateCategoryIds.contains(c.id),
                          onTap: () => _pick(.category(c.id)),
                        ),
                      if (query.isEmpty)
                        for (var i = 0; i < pending.newCategoryIds.length; i++)
                          _PendingTile(
                            label:
                                context.l10n.diary.categorySyncingPlaceholder,
                          ),
                      _Tile(
                        label: context.l10n.diary.categoryNoCategory,
                        count: uncategorized,
                        selected: filter.uncategorized,
                        leading: _Swatch.none(scheme: colors),
                        onTap: () => _pick(const .uncategorized()),
                      ),
                      _SectionHeader(
                        label: context.l10n.diary.tags,
                        count: catalog?.usage.length,
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
                      if (visible.isEmpty &&
                          visibleTags.isEmpty &&
                          query.isNotEmpty)
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
                Divider(height: 1, color: colors.outlineVariant),
                Padding(
                  padding: .only(
                    bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _Tile(
                    label: context.l10n.app.homeNavigatorSetting,
                    count: null,
                    selected: false,
                    leading: const Icon(LucideIcons.settings, size: 20),
                    onTap: () => _open(const SettingRoute()),
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
  final int? count;
  final String tooltip;
  final VoidCallback onManage;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.tooltip,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16, 4, 16, 6),
    child: Row(
      children: [
        Text(
          count == null ? label : '$label · $count',
          style: context.theme.typography.labelMedium.onSurfaceVariant,
        ),
        const Spacer(),
        SizedBox.square(
          dimension: 40,
          child: IconButton(
            tooltip: tooltip,
            icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
            onPressed: onManage,
          ),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  final int? total;

  const _Header({required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            context.l10n.common.appName,
            style: context.theme.typography.titleLarge.emphasized.onSurface,
          ),
          if (total != null)
            Padding(
              padding: const .only(top: 2),
              child: Text(
                context.l10n.diary.searchResult(count: total!),
                style: context.theme.typography.labelMedium.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;

  final int? count;
  final bool selected;
  final Widget leading;
  final bool syncing;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.count,
    required this.selected,
    required this.leading,
    this.syncing = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return Padding(
      padding: const .symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: const .all(.circular(28)),
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: onTap,
          child: Padding(
            padding: const .symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: selected
                        ? typo.bodyLarge.emphasized.onSecondaryContainer
                        : typo.bodyLarge.onSurface,
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
                                ? typo.labelMedium.onSecondaryContainer
                                : typo.labelMedium.onSurfaceVariant)
                            .copyWith(fontFeatures: const [.tabularFigures()]),
                  ),
                ],
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
  final Gradient? gradient;
  final bool hollow;

  const _Swatch({this.color}) : gradient = null, hollow = false;

  _Swatch.all({required ColorScheme scheme})
    : color = null,
      hollow = false,
      gradient = LinearGradient(colors: [scheme.primary, scheme.tertiary]);

  const _Swatch.none({required ColorScheme scheme})
    : color = null,
      gradient = null,
      hollow = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        shape: .circle,
        border: hollow ? .all(color: colors.outline, width: 1.4) : null,
      ),
    );
  }
}
