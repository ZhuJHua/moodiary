import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';

/// 首页「分类」分区的可复用主体：分类列表 + 同步占位/进行中指示。
/// 由 app 侧首页壳组合（与全部日记视图并列于 PageView）。
class DiaryCategorySectionView extends ConsumerWidget {
  const DiaryCategorySectionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryControllerProvider);
    return categoryAsync.buildLoading(
      data: (categories) {
        return ValueListenableBuilder(
          valueListenable: SyncPendingTracker.instance.listenable,
          builder: (context, pending, _) {
            // 远端将新增的分类排在已有分类之后占位，落库后由事件流原地替换。
            final placeholderCount = pending.newCategoryIds.length;
            if (categories.isEmpty && placeholderCount == 0) {
              return Center(
                child: Text(
                  '暂无分类',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                0,
                8,
                0,
                8 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: categories.length + placeholderCount,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index >= categories.length) {
                  return const _CategoryPendingRow();
                }
                final category = categories[index];
                return _CategoryRow(
                  category: category,
                  syncing: pending.updateCategoryIds.contains(category.id),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;

  final bool syncing;

  const _CategoryRow({required this.category, this.syncing = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.label_outline_rounded),
      title: Text(category.categoryName),
      trailing: syncing
          ? const SyncPendingBadge()
          : const Icon(Icons.chevron_right_rounded),
      onTap: () {
        // TODO: 点击分类后的行为待定
      },
    );
  }
}

class _CategoryPendingRow extends StatelessWidget {
  const _CategoryPendingRow();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ListTile(
      leading: Icon(Icons.label_outline_rounded, color: scheme.outline),
      title: Text(
        '正在同步分类…',
        style: context.textTheme.bodyMedium?.copyWith(color: scheme.outline),
      ),
      trailing: const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    );
  }
}
