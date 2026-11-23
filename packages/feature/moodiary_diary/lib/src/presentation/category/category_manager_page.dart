import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

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
      appBar: AppBar(title: Text(context.l10n.diary.categoryManagerTitle)),
      floatingActionButton: (async.value?.isNotEmpty ?? false)
          ? FloatingActionButton(
              heroTag: 'categoryManagerFab',
              onPressed: _onAddCategory,
              child: const Icon(LucideIcons.plus),
            )
          : null,
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
              Expanded(
                child: _buildList(filtered, counts, canReorder: q.isEmpty),
              ),
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
            onDelete: () => _onDelete(c, counts[c.id] ?? 0),
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
                  borderRadius: .circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.theme.colors.shadow.withValues(
                        alpha: 0.12 * t,
                      ),
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
            onDelete: () => _onDelete(c, counts[c.id] ?? 0),
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
          .create(categoryName: draft.name, color: draft.color, parentId: null),
        );
    if (!mounted) return;
    if (ok) {
      toast.success(message: l10n.diary.categoryCreated(name: draft.name));
    } else {
      toast.error(message: l10n.diary.categoryCreateFailed);
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
            lastModified: .timestamp(),
            parentId: category.parentId,
            color: draft.color,
          ),
        );
    if (!mounted) return;
    if (ok) {
      toast.success(message: l10n.diary.categoryRenamed(name: draft.name));
    } else {
      toast.error(message: l10n.diary.categoryRenameFailed);
    }
  }

  Future<void> _onDelete(Category category, int count) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.categoryDeleteTitle,
      message: l10n.diary.categoryDeleteMessage(
        name: category.categoryName,
        count: count,
      ),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    final ok = await ref
        .read(categoryControllerProvider.notifier)
        .deleteCategory(category.id);
    if (!mounted) return;
    if (ok) {
      toast.success(message: l10n.diary.categoryDeleted);
    } else {
      toast.error(message: l10n.common.loadFailed);
    }
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(12, 12, 12, 6),
      child: TextField(
        onChanged: onChanged,
        textInputAction: .search,
        decoration: InputDecoration(
          hintText: context.l10n.diary.categorySearchHint,
          prefixIcon: const Icon(LucideIcons.search),
          filled: true,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            borderSide: .none,
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
        context.l10n.diary.categoryNoMatch,
        style: context.theme.typography.bodyMedium.onSurfaceVariant,
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
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.folder,
            size: 48,
            color: context.theme.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.diary.categoryEmpty,
            style: context.theme.typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
            label: Text(context.l10n.diary.categoryNew),
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
    final color = categoryColorOf(colorValue: category.color, id: category.id);
    return MetaTile<String>(
      leading: MetaBadge(
        icon: LucideIcons.folder,
        background: color,
        foreground: onCategoryColor(color),
      ),
      title: category.categoryName,
      subtitle: count > 0
          ? context.l10n.diary.categoryDiaryCount(count: count)
          : context.l10n.diary.categoryNoDiary,
      dragIndex: dragIndex,
      onTap: onRename,
      entries: [
        MMenuEntry(
          value: 'rename',
          label: context.l10n.diary.rename,
          icon: LucideIcons.squarePen,
        ),
        MMenuEntry(
          value: 'delete',
          label: context.l10n.common.delete,
          icon: LucideIcons.trash2,
          isDestructive: true,
        ),
      ],
      onSelected: (key) => key == 'rename' ? onRename() : onDelete(),
    );
  }
}
