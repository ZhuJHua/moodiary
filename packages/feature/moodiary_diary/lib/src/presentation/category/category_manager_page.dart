import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_data/moodiary_data.dart';

class CategoryManagerPage extends ConsumerStatefulWidget {
  const CategoryManagerPage({super.key});

  @override
  ConsumerState<CategoryManagerPage> createState() =>
      _CategoryManagerPageState();
}

class _CategoryManagerPageState extends ConsumerState<CategoryManagerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderedCategoriesProvider);
    final counts =
        ref.watch(categoryDiaryCountsProvider).value?.byCategory ??
        const <String, int>{};
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddCategory,
        child: const Icon(Icons.add),
      ),
      body: async.buildLoading(
        data: (categories) {
          if (categories.isEmpty) {
            return _Empty(onAdd: _onAddCategory);
          }
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? categories
              : categories
                    .where((c) => c.categoryName.toLowerCase().contains(q))
                    .toList();
          return Column(
            children: [
              _SearchField(onChanged: (v) => setState(() => _query = v)),
              Expanded(child: _buildList(filtered, counts, canReorder: q.isEmpty)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
    List<Category> categories,
    Map<String, int> counts, {
    required bool canReorder,
  }) {
    if (categories.isEmpty) return const _NoMatch();
    const padding = EdgeInsets.fromLTRB(12, 4, 12, 88);
    if (!canReorder) {
      return ListView.builder(
        padding: padding,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final c = categories[index];
          return _CategoryTile(
            category: c,
            count: counts[c.id] ?? 0,
            onRename: () => _onEditCategory(c),
            onDelete: () => _onDelete(c),
          );
        },
      );
    }
    return ReorderableListView.builder(
      padding: padding,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.03 * t,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12 * t),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: child,
      ),
      onReorderItem: (oldIndex, newIndex) =>
          _onReorder(categories, oldIndex, newIndex),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final c = categories[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(c.id),
          index: index,
          child: _CategoryTile(
            category: c,
            count: counts[c.id] ?? 0,
            dragIndex: index,
            onRename: () => _onEditCategory(c),
            onDelete: () => _onDelete(c),
          ),
        );
      },
    );
  }

  void _onReorder(List<Category> ordered, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final ids = [for (final c in ordered) c.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    MoodiaryKVs.categoryOrder.getNotifierOr(const []).updateFromStorage(ids);
    MoodiaryKVs.categoryOrder.set(ids);
    HapticFeedback.mediumImpact();
  }

  Future<void> _onAddCategory() async {
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
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已创建「${draft.name}」');
    } else {
      toast.error(message: '创建失败');
    }
  }

  Future<void> _onEditCategory(Category category) async {
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
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已重命名为「${draft.name}」');
    } else {
      toast.error(message: '重命名失败');
    }
  }

  Future<void> _onDelete(Category category) async {
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
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已删除');
    } else {
      toast.error(message: '分类下仍有日记，删除失败');
    }
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.l10n.categorySearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.categoryNoMatch,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
  final int count;
  final int? dragIndex;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.count,
    this.dragIndex,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = categoryColorOf(colorValue: category.color, id: category.id);
    final onColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onRename,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.label_rounded, size: 21, color: onColor),
        ),
        title: Text(
          category.categoryName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleMedium,
        ),
        subtitle: Text(
          count > 0 ? '$count 篇日记' : '暂无日记',
          style: context.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoodiaryMenuButton<String>(
              tooltip: context.l10n.more,
              onSelected: (key) {
                switch (key) {
                  case 'rename':
                    onRename();
                  case 'delete':
                    onDelete();
                }
              },
              entries: const [
                MoodiaryMenuEntry(
                  value: 'rename',
                  label: '重命名',
                  icon: Icons.edit_outlined,
                ),
                MoodiaryMenuEntry(
                  value: 'delete',
                  label: '删除',
                  icon: Icons.delete_outline,
                  isDestructive: true,
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
            Text(ctx.l10n.categoryColorLabel, style: ctx.textTheme.labelMedium),
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
              Navigator.of(ctx).pop(CategoryDraft(name: name, color: selected));
            },
            child: Text(ctx.l10n.ok),
          ),
        ],
      ),
    ),
  );
}
