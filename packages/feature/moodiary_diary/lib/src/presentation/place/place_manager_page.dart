import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'place_editor.dart';

/// 常用地点管理。与 [CategoryManagerPage] 是同一套骨架（搜索框 + 可拖拽卡片列表 +
/// FAB + MAlert 编辑弹窗），三处刻意不同：
///
/// - 方块底色**按 id 自动取**（复用 `categoryColorOf`），不给用户选颜色——图标已经
///   承担了辨识，再加一个调色板等于为一条设置选两次；
/// - 副标题是「N 篇日记 · 半径 200 m」，日记数按**坐标落在半径内**统计，不按名字
///   匹配（名字是快照，改名就断）；
/// - 删除**不拦**。日记的 `DiaryPosition.name` 是写入时的字符串快照、不是对本表的
///   引用，删掉「公司」旧日记照样显示「公司」，只是以后不再自动命中。
class PlaceManagerPage extends ConsumerStatefulWidget {
  const PlaceManagerPage({super.key});

  @override
  ConsumerState<PlaceManagerPage> createState() => _PlaceManagerPageState();
}

class _PlaceManagerPageState extends ConsumerState<PlaceManagerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderedPlacesProvider);
    final counts = ref.watch(placeDiaryCountsProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diary.placeManagerTitle)),
      // 空态自带「新建」按钮，右下角的 FAB 只在有列表时出现，免得两个入口撞车。
      floatingActionButton: (async.value?.isNotEmpty ?? false)
          ? FloatingActionButton(
              heroTag: 'placeManagerFab',
              onPressed: _onAddPlace,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: async.buildLoading(
        data: (places) {
          if (places.isEmpty) return _Empty(onAdd: _onAddPlace);
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? places
              : places.where((p) => p.name.toLowerCase().contains(q)).toList();
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
    List<Place> places,
    Map<String, int> counts, {
    required bool canReorder,
  }) {
    if (places.isEmpty) return const _NoMatch();
    const padding = EdgeInsets.fromLTRB(12, 4, 12, 88);
    if (!canReorder) {
      return ListView.builder(
        padding: padding,
        itemCount: places.length,
        itemBuilder: (context, index) {
          final p = places[index];
          return _PlaceTile(
            place: p,
            count: counts[p.id] ?? 0,
            onEdit: () => _onEditPlace(p),
            onDelete: () => _onDelete(p),
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
          _onReorder(places, oldIndex, newIndex),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final p = places[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(p.id),
          index: index,
          child: _PlaceTile(
            place: p,
            count: counts[p.id] ?? 0,
            dragIndex: index,
            onEdit: () => _onEditPlace(p),
            onDelete: () => _onDelete(p),
          ),
        );
      },
    );
  }

  void _onReorder(List<Place> ordered, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final ids = [for (final p in ordered) p.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    MoodiaryKVs.placeOrder.getNotifierOr(const []).updateFromStorage(ids);
    MoodiaryKVs.placeOrder.set(ids);
    HapticFeedback.mediumImpact();
  }

  Future<void> _onAddPlace() async {
    final saved = await showPlaceEditor(context);
    if (saved == null || !mounted) return;
    toast.success(message: l10n.diary.placeCreated(name: saved.name));
  }

  Future<void> _onEditPlace(Place place) async {
    final saved = await showPlaceEditor(context, existing: place);
    if (saved == null || !mounted) return;
    toast.success(message: l10n.diary.placeSaved);
  }

  Future<void> _onDelete(Place place) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.placeDeleteTitle(name: place.name),
      // 「已写的日记不受影响」是这里最该说清楚的一句：地名是快照不是引用。
      message: l10n.diary.placeDeleteMessage(name: place.name),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    final ok = await ref
        .read(placeControllerProvider.notifier)
        .deletePlace(place.id);
    if (!mounted) return;
    if (ok) {
      toast.success(message: l10n.diary.placeDeleted);
    } else {
      toast.error(message: l10n.diary.placeDeleteBlocked);
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
          hintText: context.l10n.diary.placeSearchHint,
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
        context.l10n.diary.placeNoMatch,
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
            LucideIcons.mapPinned,
            size: 48,
            color: context.theme.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.diary.placeEmpty,
            style: context.theme.typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
            label: Text(context.l10n.diary.placeNew),
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final Place place;
  final int count;
  final int? dragIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaceTile({
    required this.place,
    required this.count,
    this.dragIndex,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    // 地点没有用户选的颜色，一律按 id 自动取——复用分类那套取色，两个页面的方块
    // 看起来才是同一个东西。
    final color = categoryColorOf(colorValue: null, id: place.id);
    final onColor = onCategoryColor(color);
    return Card.filled(
      margin: const .symmetric(vertical: 4),
      color: colors.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: ListTile(
        onTap: onEdit,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color, borderRadius: .circular(13)),
          child: Icon(placeIconOf(place.icon), size: 21, color: onColor),
        ),
        title: Text(
          place.name,
          maxLines: 1,
          overflow: .ellipsis,
          style: context.theme.typography.titleMedium.onSurface,
        ),
        subtitle: Text(
          count > 0
              ? context.l10n.diary.placeDiaryCount(count: count)
              : context.l10n.diary.placeNoDiary,
          style: context.theme.typography.labelSmall.onSurfaceVariant,
        ),
        trailing: Row(
          mainAxisSize: .min,
          children: [
            MMenuButton<String>(
              tooltip: context.l10n.common.more,
              onSelected: (key) {
                switch (key) {
                  case 'edit':
                    onEdit();
                  case 'delete':
                    onDelete();
                }
              },
              entries: [
                MMenuEntry(
                  value: 'edit',
                  label: context.l10n.diary.edit,
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
