import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';

class DiaryManagerPage extends ConsumerStatefulWidget {
  const DiaryManagerPage({super.key});

  @override
  ConsumerState<DiaryManagerPage> createState() => _DiaryManagerPageState();
}

class _DiaryManagerPageState extends ConsumerState<DiaryManagerPage> {
  String? _categoryFilter;
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final provider = diaryControllerProvider(categoryId: _categoryFilter);
    final async = ref.watch(provider);
    final categories = ref.watch(orderedCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty ? '日记管理' : '已选 ${_selected.length}'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: '批量移入回收站',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _onBatchSoftDelete(provider, async),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _categoryFilter,
            categoriesAsync: categories,
            onChanged: (id) => setState(() {
              _categoryFilter = id;
              _selected.clear();
            }),
          ),
          Expanded(
            child: async.buildLoading(
              data: (diaries) {
                if (diaries.isEmpty) {
                  return const Center(child: Text('当前筛选下没有日记'));
                }
                return ListView.separated(
                  itemBuilder: (context, index) {
                    final d = diaries[index];
                    final picked = _selected.contains(d.isarId);
                    return CheckboxListTile(
                      value: picked,
                      title: Text(
                        d.title.isEmpty ? '(无标题)' : d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        TimeUtil.listDateTime(d.time),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(d.isarId);
                          } else {
                            _selected.remove(d.isarId);
                          }
                        });
                      },
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemCount: diaries.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBatchSoftDelete(
    DiaryControllerProvider provider,
    AsyncValue<List<Diary>> async,
  ) async {
    final picked = _selected.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量移入回收站？'),
        content: Text('共 ${picked.length} 条日记将被移入回收站，可在「回收站」内恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移入回收站'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final list = async.value ?? const <Diary>[];
    final notifier = ref.read(provider.notifier);
    int ok = 0;
    for (final id in picked) {
      final d = list.firstWhere(
        (e) => e.isarId == id,
        // 占位，下面被 d.id.isEmpty 拦掉，type 取哪个都行。
        orElse: () => Diary.empty(type: DiaryType.richText),
      );
      if (d.id.isEmpty) continue;
      if (await notifier.softDeleteDiary(d)) ok += 1;
    }
    if (!mounted) return;
    setState(_selected.clear);
    toast.success(message: '已移入回收站 $ok / ${picked.length}');
  }
}

class _FilterBar extends StatelessWidget {
  final String? current;
  final AsyncValue categoriesAsync;
  final void Function(String?) onChanged;

  const _FilterBar({
    required this.current,
    required this.categoriesAsync,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: categoriesAsync.maybeWhen(
        data: (cats) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            ChoiceChip(
              label: const Text('全部'),
              selected: current == null,
              onSelected: (_) => onChanged(null),
            ),
            const SizedBox(width: 8),
            for (final c in cats) ...[
              ChoiceChip(
                label: Text(c.categoryName),
                selected: current == c.id,
                onSelected: (_) => onChanged(c.id),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}
