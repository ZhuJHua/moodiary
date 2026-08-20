import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

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
        title: Text(
          _selected.isEmpty
              ? context.l10n.diary.managerTitle
              : context.l10n.diary.managerSelected(count: _selected.length),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: context.l10n.diary.managerBatchRecycle,
              icon: const Icon(LucideIcons.trash2),
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
                  return Center(child: Text(context.l10n.diary.managerEmpty));
                }
                return ListView.separated(
                  itemBuilder: (context, index) {
                    final d = diaries[index];
                    final picked = _selected.contains(d.isarId);
                    return CheckboxListTile(
                      value: picked,
                      title: Text(
                        d.title.isEmpty
                            ? context.l10n.common.untitled
                            : d.title,
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                      subtitle: Text(TimeFormat.listDateTime(d.time)),
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
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.managerRecycleTitle,
      message: l10n.diary.managerRecycleMessage(count: picked.length),
      confirmLabel: l10n.diary.managerRecycleConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    final list = async.value ?? const <Diary>[];
    final notifier = ref.read(provider.notifier);
    int ok = 0;
    for (final id in picked) {
      final d = list.firstWhere(
        (e) => e.isarId == id,
        // 占位，下面被 d.id.isEmpty 拦掉，type 取哪个都行。
        orElse: () => Diary.empty(type: .richText),
      );
      if (d.id.isEmpty) continue;
      if (await notifier.softDeleteDiary(d)) ok += 1;
    }
    if (!mounted) return;
    setState(_selected.clear);
    toast.success(
      message: l10n.diary.managerRecycled(done: ok, total: picked.length),
    );
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
          scrollDirection: .horizontal,
          padding: const .symmetric(horizontal: 12, vertical: 8),
          children: [
            ChoiceChip(
              label: Text(context.l10n.diary.managerAll),
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
