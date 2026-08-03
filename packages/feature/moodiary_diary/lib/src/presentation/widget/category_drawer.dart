import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_diary/src/application/diary_filter.dart';
import 'package:moodiary_diary/src/application/diary_selection.dart';

/// 分类超过这个数才在抽屉里出现搜索框 —— 三五个分类时搜索框只是噪音。
const int _kSearchThreshold = 8;

/// 首页的分类抽屉：品牌区 + 全部 / 各分类 / 未分类 + 底部「管理分类」。
///
/// 必须挂在**根壳**的 Scaffold 上：首页只是 IndexedStack 里的一个 tab，抽屉挂在它
/// 自己那层会被底部 NavigationBar 截断，只盖住内容区。
class CategoryDrawer extends ConsumerStatefulWidget {
  const CategoryDrawer({super.key});

  @override
  ConsumerState<CategoryDrawer> createState() => _CategoryDrawerState();
}

class _CategoryDrawerState extends ConsumerState<CategoryDrawer> {
  String _query = '';

  void _pick(DiaryFilter filter) {
    // 换筛选必须清空多选：选中的 id 属于**旧**筛选，跨维度存活的话
    // softDeleteByIds 会在新列表里一条都匹配不上，删除变成静默空操作。
    ref.read(diarySelectionProvider.notifier).clear();
    ref.read(homeDiaryFilterProvider.notifier).select(filter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final filter = ref.watch(homeDiaryFilterProvider);
    final categories = ref.watch(orderedCategoriesProvider).value ?? const [];
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    // 查询没回来时一律传 null 让数字整个不显示 —— 先铺一屏 0 再跳成真实值，
    // 比空着更像出了错。
    final total = counts?.total;
    // 未分类篇数 = 可见总数 − 各分类之和，不必再查一次库。
    final uncategorized = counts == null
        ? null
        : (counts.total -
                  counts.byCategory.values.fold<int>(0, (a, b) => a + b))
              .clamp(0, counts.total);

    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? categories
        : categories
              .where((c) => c.categoryName.toLowerCase().contains(query))
              .toList();

    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: SyncPendingTracker.instance.listenable,
          builder: (context, pending, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(total: total),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.editCategory,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.categorySwitcherCount(categories.length),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (categories.length >= _kSearchThreshold)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SearchBar(
                      hintText: context.l10n.categorySearchHint,
                      leading: const Icon(Icons.search_rounded, size: 20),
                      constraints: const BoxConstraints(minHeight: 42),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        scheme.surfaceContainerHigh,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      // 搜索时只留搜索结果：「全部日记」与「同步中」占位行永远匹配
                      // 不上查询，混在结果里会和下面的「没有匹配的分类」自相矛盾。
                      if (query.isEmpty)
                        _Tile(
                          label: context.l10n.categoryAllDiary,
                          count: total,
                          selected: filter.isAll,
                          leading: _Swatch.all(scheme: scheme),
                          onTap: () => _pick(const DiaryFilter.all()),
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
                          onTap: () => _pick(DiaryFilter.category(c.id)),
                        ),
                      // 新建但还没同步上去的分类：没有名字可显示，只表明「还有东西在路上」。
                      if (query.isEmpty)
                        for (var i = 0; i < pending.newCategoryIds.length; i++)
                          _PendingTile(
                            label: context.l10n.categorySyncingPlaceholder,
                          ),
                      if (visible.isEmpty && query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            context.l10n.categoryNoMatch,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                // 抽屉不随键盘缩，底部这两项会被输入法整个盖住 —— 手动让位。
                // 「未分类」不是一个分类，是「缺少分类」——所以放在分隔线以下、
                // 和管理入口一组，而不是混进分类列表里。
                _Tile(
                  label: context.l10n.categoryNoCategory,
                  count: uncategorized,
                  selected: filter.uncategorized,
                  leading: _Swatch.none(scheme: scheme),
                  onTap: () => _pick(const DiaryFilter.uncategorized()),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    12 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            const CategoryManagerRoute().push(context);
                          },
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(context.l10n.categoryManageEntry),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 设置从底栏挪进来了：底栏只剩三个 tab，而抽屉本来就是「离开当前
                      // 内容去别处」的那一栏。
                      IconButton.filledTonal(
                        tooltip: context.l10n.homeNavigatorSetting,
                        onPressed: () {
                          Navigator.of(context).pop();
                          const SettingRoute().push(context);
                        },
                        icon: const Icon(Icons.settings_rounded, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 44),
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

class _Header extends StatelessWidget {
  /// null = 计数查询还没回来，副标题整行留空而不是写「共有 0 篇」。
  final int? total;

  const _Header({required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.appName,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (total != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.l10n.diarySearchResult(total!),
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;

  /// 篇数；null = 计数查询还没回来，此时整个数字不显示。
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
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (syncing) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类色点。「全部」用主题色渐变、「未分类」用一圈虚线描边 —— 三者一眼能分。
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
    final scheme = context.colorScheme;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        shape: BoxShape.circle,
        border: hollow ? Border.all(color: scheme.outline, width: 1.4) : null,
      ),
    );
  }
}
