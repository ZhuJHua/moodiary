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
        heroTag: 'categoryManagerFab',
        onPressed: _onAddCategory,
        child: const Icon(LucideIcons.plus),
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
    final confirmed = await showMoodiaryConfirm(
      context,
      title: '删除分类？',
      message: '"${category.categoryName}" 下若仍有日记将无法删除。本操作不会影响日记本身。',
      confirmLabel: '删除',
      isDestructive: true,
    );
    if (!confirmed) return;
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
          prefixIcon: const Icon(LucideIcons.search),
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
          const Icon(LucideIcons.folder, size: 48),
          const SizedBox(height: 12),
          Text('暂无分类', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
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
          child: Icon(LucideIcons.folder, size: 21, color: onColor),
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
                  icon: LucideIcons.squarePen,
                ),
                MoodiaryMenuEntry(
                  value: 'delete',
                  label: '删除',
                  icon: LucideIcons.trash2,
                  isDestructive: true,
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  LucideIcons.ellipsisVertical,
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
                    LucideIcons.gripHorizontal,
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

const _emptyNameError = '分类名称不能为空';

Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String initialName,
  required int? initialColor,
}) async {
  // 名字与颜色两个值要一起回传，弹窗按钮的返回值是静态的，所以用可变 holder 承接
  // 内容区的实时编辑结果，按钮只负责回答「确认还是取消」。
  final draft = _CategoryDraft(name: initialName, color: initialColor);
  final contentKey = GlobalKey<_CategoryEditorContentState>();
  final confirmed = await showMoodiaryAlert<bool>(
    context,
    content: _CategoryEditorContent(key: contentKey, draft: draft),
    actions: [
      MoodiaryAction(label: context.l10n.cancel, value: false),
      MoodiaryAction(
        label: context.l10n.ok,
        value: true,
        isPrimary: true,
        // 空名不放行：就地亮红字并留住弹窗，而不是关掉再 toast 骂人。
        onIntercept: () => contentKey.currentState?.validate() ?? false,
      ),
    ],
  );
  if (confirmed != true) return null;
  return CategoryDraft(name: draft.name.trim(), color: draft.color);
}

class _CategoryDraft {
  String name;
  int? color;

  _CategoryDraft({required this.name, required this.color});
}

class _CategoryEditorContent extends StatefulWidget {
  final _CategoryDraft draft;

  const _CategoryEditorContent({super.key, required this.draft});

  @override
  State<_CategoryEditorContent> createState() => _CategoryEditorContentState();
}

class _CategoryEditorContentState extends State<_CategoryEditorContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.name,
  );

  /// 一进来就红字太吵，用户动过输入框、或点了确认之后才提示空名。
  bool _edited = false;

  /// 供确认键拦截使用：名字非空才放行，否则亮出错误提示。
  bool validate() {
    final ok = widget.draft.name.trim().isNotEmpty;
    if (!ok && !_edited) setState(() => _edited = true);
    return ok;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          borderSide: side,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (value) => setState(() {
            _edited = true;
            widget.draft.name = value;
          }),
          style: context.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: '分类名称',
            errorText: _edited && widget.draft.name.trim().isEmpty
                ? _emptyNameError
                : null,
            filled: true,
            isDense: true,
            fillColor: scheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(
              BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.categoryColorLabel,
          style: context.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCategoryPalette)
              GestureDetector(
                key: ValueKey('category-swatch-${c.toARGB32()}'),
                onTap: () => setState(() => widget.draft.color = c.toARGB32()),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.draft.color == c.toARGB32()
                          ? scheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
