import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/application/search_controller.dart';
import 'package:moodiary_diary/src/presentation/search/search_result_card.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

/// 日记搜索页：AppBar 内嵌搜索框，下方筛选栏（时间 / 分类 / 排序）；空查询时展示搜索历史。
class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({super.key});

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  DiarySearchController get _controller =>
      ref.read(diarySearchControllerProvider.notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _controller.search(text);
    });
  }

  void _searchNow() {
    _debounce?.cancel();
    _controller
      ..search(_textController.text)
      ..recordHistory();
  }

  void _useHistory(String q) {
    _textController.text = q;
    _textController.selection = .collapsed(offset: q.length);
    _controller
      ..search(q)
      ..recordHistory();
  }

  void _clearInput() {
    _textController.clear();
    _controller.search('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diarySearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          maxLines: 1,
          autofocus: true,
          controller: _textController,
          focusNode: _focusNode,
          textInputAction: .search,
          onChanged: _onChanged,
          onSubmitted: (_) => _searchNow(),
          decoration: InputDecoration(
            border: .none,
            hintText: context.l10n.diary.search,
            suffixIcon: ValueListenableBuilder(
              valueListenable: _textController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: _clearInput,
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _SearchIndexBanner(),
            _buildFilterBar(context, state),
            Expanded(
              child: AnimatedSwitcher(
                duration: Durations.short3,
                child: _buildBody(context, state),
              ),
            ),
            if (state.query.isNotEmpty)
              Padding(
                padding: const .all(8.0),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      context.l10n.diary.searchResult(count: state.totalCount),
                    ),
                    if (state.elapsed != null)
                      Text(
                        ' · ${context.l10n.diary.searchTime(ms: state.elapsed!.inMilliseconds)}',
                        style:
                            context.theme.typography.bodySmall.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 筛选栏 ────────────────────────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context, DiarySearchState state) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          _dateChip(context, state),
          const SizedBox(width: 8),
          _categoryChip(context, state),
          const SizedBox(width: 8),
          _sortChip(context, state),
        ],
      ),
    );
  }

  Widget _dateChip(BuildContext context, DiarySearchState state) {
    return MMenuButton<DateRangePreset>(
      selected: state.datePreset,
      onSelected: (preset) async {
        if (preset == .custom) {
          final now = DateTime.now();
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2015),
            lastDate: now,
            initialDateRange:
                (state.customStart != null && state.customEnd != null)
                ? DateTimeRange(
                    start: state.customStart!,
                    end: state.customEnd!,
                  )
                : null,
            switchToInputEntryModeIcon: const Icon(LucideIcons.keyboard),
            switchToCalendarEntryModeIcon: const Icon(LucideIcons.calendarDays),
          );
          if (range != null) _controller.setCustomRange(range.start, range.end);
        } else {
          _controller.setDatePreset(preset);
        }
      },
      entries: [
        for (final p in DateRangePreset.values)
          MMenuEntry(value: p, label: _dateLabel(context, p)),
      ],
      child: _FilterChip(
        icon: LucideIcons.calendar,
        label: _dateChipLabel(context, state),
        active: state.datePreset != .all,
      ),
    );
  }

  Widget _categoryChip(BuildContext context, DiarySearchState state) {
    final categories = ref
        .watch(orderedCategoriesProvider)
        .when(
          data: (d) => d,
          loading: () => const <Category>[],
          error: (_, _) => const <Category>[],
        );
    final label = state.categoryId == null
        ? context.l10n.diary.allCategories
        : (categories
                  .firstWhereOrNull((c) => c.id == state.categoryId)
                  ?.categoryName ??
              context.l10n.diary.allCategories);
    return MMenuButton<String>(
      // 空串 = 全部分类（null 语义留给「未选择」，故用空串表达「全部」）。
      selected: state.categoryId ?? '',
      onSelected: (id) => _controller.setCategory(id.isEmpty ? null : id),
      entries: [
        MMenuEntry(value: '', label: context.l10n.diary.allCategories),
        for (final c in categories)
          MMenuEntry(value: c.id, label: c.categoryName),
      ],
      child: _FilterChip(
        icon: LucideIcons.folder,
        label: label,
        active: state.categoryId != null,
      ),
    );
  }

  Widget _sortChip(BuildContext context, DiarySearchState state) {
    return MMenuButton<SearchSort>(
      selected: state.sort,
      onSelected: _controller.setSort,
      entries: [
        for (final s in SearchSort.values)
          MMenuEntry(value: s, label: _sortLabel(context, s)),
      ],
      child: _FilterChip(
        icon: LucideIcons.arrowUpDown,
        label: _sortLabel(context, state.sort),
        active: state.sort != .relevance,
      ),
    );
  }

  String _dateLabel(BuildContext context, DateRangePreset p) => switch (p) {
    .all => context.l10n.diary.rangeAll,
    .last7Days => context.l10n.diary.rangeLast7,
    .last30Days => context.l10n.diary.rangeLast30,
    .thisYear => context.l10n.diary.rangeThisYear,
    .custom => context.l10n.common.custom,
  };

  String _dateChipLabel(BuildContext context, DiarySearchState state) {
    if (state.datePreset == .custom &&
        state.customStart != null &&
        state.customEnd != null) {
      final f = DateFormat.Md();
      return '${f.format(state.customStart!)} – ${f.format(state.customEnd!)}';
    }
    return _dateLabel(context, state.datePreset);
  }

  String _sortLabel(BuildContext context, SearchSort s) => switch (s) {
    .relevance => context.l10n.diary.searchSortRelevance,
    .timeDesc => context.l10n.diary.searchSortNewest,
    .timeAsc => context.l10n.diary.searchSortOldest,
  };

  // ── 主体（历史 / 结果 / 空 / 加载） ──────────────────────────────────────

  Widget _buildBody(BuildContext context, DiarySearchState state) {
    if (state.isSearching && state.results.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (state.results.isNotEmpty) {
      return Stack(
        key: const ValueKey('list'),
        children: [
          Positioned.fill(
            child: ListView.separated(
              itemCount: state.results.length,
              padding: const .all(12),
              itemBuilder: (context, index) => SearchResultCard(
                diary: state.results[index],
                queryList: state.queryList,
                onTap: _controller.recordHistory,
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
            ),
          ),
          if (state.isSearching)
            Positioned.fill(
              child: ColoredBox(
                color: context.theme.colors.surfaceContainer.withValues(
                  alpha: 0.8,
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    }
    if (state.query.isEmpty) return _historyView(context);
    return _placeholder(
      context,
      key: 'empty',
      icon: LucideIcons.searchX,
      text: context.l10n.diary.searchNoResult,
    );
  }

  Widget _historyView(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      key: const ValueKey('history'),
      valueListenable: MoodiaryKVs.searchHistory.getNotifierOr(
        const <String>[],
      ),
      builder: (context, history, _) {
        if (history.isEmpty) {
          return _placeholder(
            context,
            key: 'history-empty',
            icon: LucideIcons.history,
            text: context.l10n.diary.searchHistoryEmpty,
          );
        }
        return SingleChildScrollView(
          padding: const .fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.diary.searchHistory,
                    style: context.theme.typography.labelLarge.onSurfaceVariant,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _controller.clearHistory,
                    icon: const Icon(LucideIcons.eraser, size: 18),
                    label: Text(context.l10n.diary.searchHistoryClear),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in history)
                    InputChip(
                      avatar: const Icon(LucideIcons.history, size: 18),
                      // 限宽 + 省略，避免超长查询（粘贴串 / 长 URL）撑破胶囊。
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(q, maxLines: 1, overflow: .ellipsis),
                      ),
                      onPressed: () => _useHistory(q),
                      onDeleted: () => _controller.removeHistory(q),
                      deleteIcon: const Icon(LucideIcons.x, size: 18),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String text,
  }) {
    final scheme = context.theme.colors;
    return Center(
      key: ValueKey(key),
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            style: context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// 升级提示卡片：全文 / 双链倒排索引 2.8.0 才引入，旧库既有日记未建索引 → 正文搜不到、双链为空。
/// 点「重建」一次即可（[DiaryRepository.rebuildAllIndexes]）；完成后置 [MoodiaryKVs.searchIndexBackfilled]，
/// 本卡片经 notifier 自动收起。全新安装在迁移钩子里已置位，不会显示。
class _SearchIndexBanner extends StatefulWidget {
  const _SearchIndexBanner();

  @override
  State<_SearchIndexBanner> createState() => _SearchIndexBannerState();
}

class _SearchIndexBannerState extends State<_SearchIndexBanner> {
  bool _rebuilding = false;

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    try {
      // 重建完成即置位 searchIndexBackfilled，外层 ValueListenableBuilder 收起本卡片。
      await DiaryRepository.get().rebuildAllIndexes();
    } catch (e, s) {
      logger.e('搜索索引重建失败', error: e, stackTrace: s);
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.searchIndexBackfilled.getNotifier(),
      builder: (context, done, _) {
        if (done) return const SizedBox.shrink();
        final scheme = context.theme.colors;
        return Container(
          margin: const .fromLTRB(12, 10, 12, 0),
          padding: const .fromLTRB(12, 8, 8, 8),
          decoration: ShapeDecoration(
            color: scheme.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: .circular(12)),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.textSearch,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.diary.searchReindexHint,
                  style:
                      context.theme.typography.bodySmall.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              if (_rebuilding)
                const Padding(
                  padding: .symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: _rebuild,
                  child: Text(context.l10n.diary.searchReindex),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 筛选栏上的下拉胶囊：填充式软色调，选中态用次级容器色高亮。
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    final bg = active
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final fg = active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: Durations.short3,
      curve: Curves.easeOut,
      padding: const .fromLTRB(14, 9, 10, 9),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.typography.labelLarge.emphasized.onSurface.copyWith(
              color: fg,
            ),
          ),
          const SizedBox(width: 1),
          Icon(LucideIcons.chevronDown, size: 18, color: fg),
        ],
      ),
    );
  }
}
