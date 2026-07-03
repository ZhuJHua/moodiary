import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 单页日记选择器：搜索 + 列表，点选一篇后经 `context.pop(diary)` 返回给调用方。
/// 供「发送日记给 AI」使用，但本身与助手解耦（只返回 [Diary]）。
class DiarySelectPage extends ConsumerStatefulWidget {
  const DiarySelectPage({super.key});

  @override
  ConsumerState<DiarySelectPage> createState() => _DiarySelectPageState();
}

class _DiarySelectPageState extends ConsumerState<DiarySelectPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  Future<List<Diary>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_query.isNotEmpty || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      ref.read(diaryControllerProvider(categoryId: null).notifier).loadMore();
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = value.trim();
      setState(() {
        _query = q;
        _searchFuture = q.isEmpty
            ? null
            : DiaryRepository.get().searchDiariesByText(q);
      });
    });
  }

  void _select(Diary diary) => context.pop(diary);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantSelectDiaryTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.assistantSelectDiarySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: const OutlineInputBorder(
                  borderRadius: AppBorderRadius.largeBorderRadius,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _query.isEmpty ? _buildAll() : _buildSearch(),
    );
  }

  Widget _buildAll() {
    final async = ref.watch(diaryControllerProvider(categoryId: null));
    return async.buildLoading(
      data: (list) {
        if (list.isEmpty) return _Empty();
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _DiarySelectTile(
            diary: list[index],
            onTap: () => _select(list[index]),
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return FutureBuilder<List<Diary>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: MoodiaryLoading());
        }
        final list = snapshot.data ?? const <Diary>[];
        if (list.isEmpty) return _Empty();
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _DiarySelectTile(
            diary: list[index],
            onTap: () => _select(list[index]),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.assistantSelectDiaryEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _DiarySelectTile extends StatelessWidget {
  final Diary diary;
  final VoidCallback onTap;

  const _DiarySelectTile({required this.diary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final title = diary.title.trim();
    final preview = diary.contentText.trim().removeLineBreaks();
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.isEmpty ? l10n.assistantDiaryUntitled : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                DateFormat.yMMMMEEEEd().add_Hm().format(diary.time),
                style: context.textTheme.labelSmall?.copyWith(
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
