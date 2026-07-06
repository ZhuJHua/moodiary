import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_diary/src/application/search_controller.dart';
import 'package:moodiary_diary/src/presentation/search/search_result_card.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

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
    _textController.selection = TextSelection.collapsed(offset: q.length);
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
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _searchNow(),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: context.l10n.diarySearch,
            suffixIcon: ValueListenableBuilder(
              valueListenable: _textController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.close_rounded),
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
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.diarySearchResult(state.totalCount)),
                    if (state.elapsed != null)
                      Text(
                        ' · ${context.l10n.diarySearchTime(state.elapsed!.inMilliseconds)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
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
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
    return MoodiaryMenuButton<DateRangePreset>(
      selected: state.datePreset,
      onSelected: (preset) async {
        if (preset == DateRangePreset.custom) {
          final now = DateTime.now();
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2015),
            lastDate: now,
            initialDateRange:
                (state.customStart != null && state.customEnd != null)
                ? DateTimeRange(start: state.customStart!, end: state.customEnd!)
                : null,
          );
          if (range != null) _controller.setCustomRange(range.start, range.end);
        } else {
          _controller.setDatePreset(preset);
        }
      },
      entries: [
        for (final p in DateRangePreset.values)
          MoodiaryMenuEntry(value: p, label: _dateLabel(context, p)),
      ],
      child: _FilterChip(
        icon: Icons.calendar_today_rounded,
        label: _dateChipLabel(context, state),
        active: state.datePreset != DateRangePreset.all,
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
        ? context.l10n.searchCategoryAll
        : (categories
                  .firstWhereOrNull((c) => c.id == state.categoryId)
                  ?.categoryName ??
              context.l10n.searchCategoryAll);
    return MoodiaryMenuButton<String>(
      // 空串 = 全部分类（null 语义留给「未选择」，故用空串表达「全部」）。
      selected: state.categoryId ?? '',
      onSelected: (id) => _controller.setCategory(id.isEmpty ? null : id),
      entries: [
        MoodiaryMenuEntry(value: '', label: context.l10n.searchCategoryAll),
        for (final c in categories)
          MoodiaryMenuEntry(value: c.id, label: c.categoryName),
      ],
      child: _FilterChip(
        icon: Icons.label_outline_rounded,
        label: label,
        active: state.categoryId != null,
      ),
    );
  }

  Widget _sortChip(BuildContext context, DiarySearchState state) {
    return MoodiaryMenuButton<SearchSort>(
      selected: state.sort,
      onSelected: _controller.setSort,
      entries: [
        for (final s in SearchSort.values)
          MoodiaryMenuEntry(value: s, label: _sortLabel(context, s)),
      ],
      child: _FilterChip(
        icon: Icons.sort_rounded,
        label: _sortLabel(context, state.sort),
        active: state.sort != SearchSort.relevance,
      ),
    );
  }

  String _dateLabel(BuildContext context, DateRangePreset p) => switch (p) {
    DateRangePreset.all => context.l10n.searchRangeAll,
    DateRangePreset.last7Days => context.l10n.searchRange7d,
    DateRangePreset.last30Days => context.l10n.searchRange30d,
    DateRangePreset.thisYear => context.l10n.searchRangeYear,
    DateRangePreset.custom => context.l10n.searchRangeCustom,
  };

  String _dateChipLabel(BuildContext context, DiarySearchState state) {
    if (state.datePreset == DateRangePreset.custom &&
        state.customStart != null &&
        state.customEnd != null) {
      final f = DateFormat.Md();
      return '${f.format(state.customStart!)} – ${f.format(state.customEnd!)}';
    }
    return _dateLabel(context, state.datePreset);
  }

  String _sortLabel(BuildContext context, SearchSort s) => switch (s) {
    SearchSort.relevance => context.l10n.searchSortRelevance,
    SearchSort.timeDesc => context.l10n.searchSortNewest,
    SearchSort.timeAsc => context.l10n.searchSortOldest,
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
              padding: const EdgeInsets.all(12),
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
                color: context.colorScheme.surfaceContainer.withValues(
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
      icon: Icons.search_off_rounded,
      text: context.l10n.searchNoResult,
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
            icon: Icons.history_rounded,
            text: context.l10n.searchHistoryEmpty,
          );
        }
        final scheme = context.colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.searchHistory,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _controller.clearHistory,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(context.l10n.searchHistoryClear),
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
                      avatar: const Icon(Icons.history_rounded, size: 18),
                      // 限宽 + 省略，避免超长查询（粘贴串 / 长 URL）撑破胶囊。
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          q,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => _useHistory(q),
                      onDeleted: () => _controller.removeHistory(q),
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
    final scheme = context.colorScheme;
    return Center(
      key: ValueKey(key),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
      await DiaryRepository.get().rebuildAllIndexes();
      // flag 置 true 后，外层 ValueListenableBuilder 收起本卡片，无需再 setState。
      await MoodiaryKVs.searchIndexBackfilled.set(true);
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
        final scheme = context.colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: ShapeDecoration(
            color: scheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.manage_search_rounded,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '升级后需重建索引，旧日记正文才能被搜索到',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_rebuilding)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(onPressed: _rebuild, child: const Text('重建')),
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
    final scheme = context.colorScheme;
    final bg = active ? scheme.secondaryContainer : scheme.surfaceContainerHighest;
    final fg = active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: Durations.short3,
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 1),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
        ],
      ),
    );
  }
}
