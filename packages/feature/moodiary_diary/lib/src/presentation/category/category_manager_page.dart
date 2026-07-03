import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_data/moodiary_data.dart';

class CategoryManagerPage extends ConsumerWidget {
  const CategoryManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddCategory(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.buildLoading(
        data: (categories) {
          if (categories.isEmpty) {
            return _Empty(onAdd: () => _onAddCategory(context, ref));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final c = categories[index];
              return _CategoryTile(
                category: c,
                onRename: () => _onEditCategory(context, ref, c),
                onDelete: () => _onDelete(context, ref, c),
              );
            },
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemCount: categories.length,
          );
        },
      ),
    );
  }

  Future<void> _onAddCategory(BuildContext context, WidgetRef ref) async {
    final draft = await showCategoryEditor(
      context,
      initialName: '',
      initialColor: null,
    );
    if (draft == null) return;
    final ok = await ref
        .read(categoryControllerProvider.notifier)
        .upsertCategory(
          Category.create(
            categoryName: draft.name,
            color: draft.color,
            parentId: null,
          ),
        );
    if (ok) {
      toast.success(message: '已创建「${draft.name}」');
    } else {
      toast.error(message: '创建失败');
    }
  }

  Future<void> _onEditCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final draft = await showCategoryEditor(
      context,
      initialName: category.categoryName,
      initialColor: category.color,
    );
    if (draft == null ||
        (draft.name == category.categoryName &&
            draft.color == category.color)) {
      return;
    }
    final ok = await ref
        .read(categoryControllerProvider.notifier)
        .upsertCategory(
          Category(
            id: category.id,
            categoryName: draft.name,
            lastModified: DateTime.timestamp(),
            parentId: category.parentId,
            color: draft.color,
            deleted: category.deleted,
          ),
        );
    if (ok) {
      toast.success(message: '已重命名为「${draft.name}」');
    } else {
      toast.error(message: '重命名失败');
    }
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类？'),
        content: Text('"${category.categoryName}" 下若仍有日记将无法删除。本操作不会影响日记本身。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(categoryControllerProvider.notifier)
        .deleteCategory(category.id);
    if (ok) {
      toast.success(message: '已删除');
    } else {
      toast.error(message: '分类下仍有日记，删除失败');
    }
  }
}

class CategoryDraft {
  final String name;
  final int? color;

  const CategoryDraft({required this.name, required this.color});
}

Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String initialName,
  required int? initialColor,
}) {
  final controller = TextEditingController(text: initialName);
  int? selected = initialColor;
  return showDialog<CategoryDraft>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '分类名称'),
            ),
            const SizedBox(height: 16),
            Text(
              ctx.l10n.categoryColorLabel,
              style: ctx.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kCategoryPalette)
                  GestureDetector(
                    key: ValueKey('category-swatch-${c.toARGB32()}'),
                    onTap: () => setState(() => selected = c.toARGB32()),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == c.toARGB32()
                              ? ctx.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(
                ctx,
              ).pop(CategoryDraft(name: name, color: selected));
            },
            child: Text(ctx.l10n.ok),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_outline, size: 48),
          const SizedBox(height: 12),
          Text('暂无分类', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('新建分类'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(category.categoryName),
      trailing: PopupMenuButton<String>(
        onSelected: (key) {
          switch (key) {
            case 'rename':
              onRename();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('重命名')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
