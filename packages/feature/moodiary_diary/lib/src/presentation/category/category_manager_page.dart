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

  Future<void> _onDelete(Category category) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.categoryDeleteTitle,
      message: l10n.diary.categoryDeleteMessage(name: category.categoryName),
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
      toast.error(message: l10n.diary.categoryDeleteBlocked);
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
    final colors = context.theme.colors;
    final color = categoryColorOf(colorValue: category.color, id: category.id);
    final onColor = onCategoryColor(color);
    return Card.filled(
      margin: const .symmetric(vertical: 4),
      color: colors.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: ListTile(
        onTap: onRename,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color, borderRadius: .circular(13)),
          child: Icon(LucideIcons.folder, size: 21, color: onColor),
        ),
        title: Text(
          category.categoryName,
          maxLines: 1,
          overflow: .ellipsis,
          style: context.theme.typography.titleMedium.onSurface,
        ),
        subtitle: Text(
          count > 0
              ? context.l10n.diary.categoryDiaryCount(count: count)
              : context.l10n.diary.categoryNoDiary,
          style: context.theme.typography.labelSmall.onSurfaceVariant,
        ),
        trailing: Row(
          mainAxisSize: .min,
          children: [
            MMenuButton<String>(
              tooltip: context.l10n.common.more,
              onSelected: (key) {
                switch (key) {
                  case 'rename':
                    onRename();
                  case 'delete':
                    onDelete();
                }
              },
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
              child: Padding(
                padding: const .all(12),
                child: Icon(
                  LucideIcons.ellipsisVertical,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: Padding(
                  padding: const .only(left: 4),
                  child: Icon(
                    LucideIcons.gripHorizontal,
                    color: colors.onSurfaceVariant,
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

String get _emptyNameError => l10n.diary.categoryNameEmpty;

Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String initialName,
  required int? initialColor,
}) async {
  // 名字与颜色两个值要一起回传，弹窗按钮的返回值是静态的，所以用可变 holder 承接
  // 内容区的实时编辑结果，按钮只负责回答「确认还是取消」。
  final draft = _CategoryDraft(name: initialName, color: initialColor);
  final contentKey = GlobalKey<_CategoryEditorContentState>();
  final confirmed = await MAlert.show<bool>(
    context,
    content: _CategoryEditorContent(key: contentKey, draft: draft),
    actions: [
      MAction(label: context.l10n.common.cancel, value: false),
      MAction(
        label: context.l10n.common.ok,
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
    final colors = context.theme.colors;
    OutlineInputBorder border([BorderSide side = .none]) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: side,
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: .done,
          onChanged: (value) => setState(() {
            _edited = true;
            widget.draft.name = value;
          }),
          style: context.theme.typography.bodyLarge.onSurface,
          decoration: InputDecoration(
            hintText: context.l10n.diary.categoryNameHint,
            errorText: _edited && widget.draft.name.trim().isEmpty
                ? _emptyNameError
                : null,
            filled: true,
            isDense: true,
            fillColor: colors.surfaceContainerHighest,
            contentPadding: const .symmetric(horizontal: 16, vertical: 13),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(
              BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.diary.categoryColorLabel,
          style: context.theme.typography.labelMedium.onSurfaceVariant,
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
                    shape: .circle,
                    border: .all(
                      color: widget.draft.color == c.toARGB32()
                          ? colors.onSurface
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
