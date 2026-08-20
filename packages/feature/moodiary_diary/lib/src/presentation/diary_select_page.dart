import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// 单页日记选择器：搜索 + 列表，点选一篇后经 `context.pop(diary)` 返回给调用方。
/// 供「发送日记给 AI」使用，但本身与助手解耦（只返回 [Diary]）。
class DiarySelectPage extends ConsumerStatefulWidget {
  const DiarySelectPage({super.key});

  @override
  ConsumerState<DiarySelectPage> createState() => _DiarySelectPageState();
}

class _DiarySelectPageState extends ConsumerState<DiarySelectPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Future<List<Diary>>? _searchFuture;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
    final colors = context.theme.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diary.assistantSelectDiaryTitle),
        bottom: PreferredSize(
          preferredSize: const .fromHeight(60),
          child: Padding(
            padding: const .fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: .search,
              decoration: InputDecoration(
                hintText: l10n.diary.assistantSelectDiarySearchHint,
                prefixIcon: const Icon(LucideIcons.search),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                isDense: true,
                contentPadding: const .symmetric(vertical: 4),
                border: const OutlineInputBorder(
                  borderRadius: AppBorderRadius.largeBorderRadius,
                  borderSide: .none,
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
    final provider = diaryControllerProvider(categoryId: null);
    final async = ref.watch(provider);
    return async.buildLoading(
      data: (list) {
        if (list.isEmpty) return _Empty();
        return MRefresh(
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          child: ListView.separated(
            padding: const .all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _DiarySelectTile(
              diary: list[index],
              onTap: () => _select(list[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return FutureBuilder<List<Diary>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == .waiting) {
          return const Center(child: MLoading());
        }
        final list = snapshot.data ?? const <Diary>[];
        if (list.isEmpty) return _Empty();
        return ListView.separated(
          padding: const .all(12),
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
    return Center(
      child: Padding(
        padding: const .all(24),
        child: Text(
          context.l10n.diary.assistantSelectDiaryEmpty,
          textAlign: .center,
          style: context.theme.typography.bodyMedium.onSurfaceVariant,
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
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final l10n = context.l10n;
    final title = diary.title.trim();
    final preview = diary.contentText.preview();
    return Card.filled(
      color: colors.surfaceContainerLow,
      margin: .zero,
      child: MInkWell(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        onTap: onTap,
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              Text(
                title.isEmpty ? l10n.common.untitled : title,
                maxLines: 1,
                overflow: .ellipsis,
                style: typo.titleSmall.onSurface,
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: typo.bodySmall.onSurfaceVariant,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                TimeFormat.fullDateTime(diary.time),
                style: typo.labelSmall.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
