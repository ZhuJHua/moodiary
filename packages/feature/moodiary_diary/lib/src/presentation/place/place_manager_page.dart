import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'place_editor.dart';
import 'place_merge_sheet.dart';

class PlaceManagerPage extends ConsumerStatefulWidget {
  const PlaceManagerPage({super.key});

  @override
  ConsumerState<PlaceManagerPage> createState() => _PlaceManagerPageState();
}

class _PlaceManagerPageState extends ConsumerState<PlaceManagerPage> {
  String _query = '';
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderedPlacesProvider);
    final counts = {
      for (final MapEntry(:key, :value)
          in (ref.watch(placeFootprintsProvider).value ?? const {}).entries)
        key: value.count,
    };
    final l10n = context.l10n;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selecting
                ? l10n.diary.placeSelectedTitle(count: _selected.length)
                : l10n.diary.placeManagerTitle,
          ),
          actions: [
            if (_selecting) ...[
              TextButton(
                onPressed: _selected.length >= 2 ? _onMerge : null,
                child: Text(l10n.diary.placeMerge),
              ),
              TextButton(
                onPressed: _exitSelection,
                child: Text(l10n.common.cancel),
              ),
            ],
          ],
        ),
        floatingActionButton: (async.value?.isNotEmpty ?? false) && !_selecting
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
                : places
                      .where((p) => p.name.toLowerCase().contains(q))
                      .toList();
            if (_selecting) {
              return _buildList(filtered, counts, canReorder: false);
            }
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
            selecting: _selecting,
            selected: _selected.contains(p.id),
            onToggle: () => _toggleSelect(p.id),
            onLongPress: () => _enterSelection(p.id),
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
            onLongPress: () => _enterSelection(p.id),
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

  void _enterSelection(String id) {
    if (_selecting) return;
    HapticFeedback.mediumImpact();
    // 多选态会收起搜索框：查询留着就成了看不见的过滤器，还会把可合并的
    // 候选限制在最初那次搜索的结果里。
    setState(() {
      _query = '';
      _selected.add(id);
    });
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _exitSelection() => setState(_selected.clear);

  Future<void> _onMerge() async {
    final places = ref.read(orderedPlacesProvider).value ?? const <Place>[];
    final selected = [
      for (final p in places)
        if (_selected.contains(p.id)) p,
    ];
    if (selected.length < 2) {
      toast.info(message: l10n.diary.placeMergeMinTwo);
      return;
    }
    // 弹层自驱整个合并流程（二次确认、进度、撤销倒计时、结果气泡）。
    final outcome = await showPlaceMergeSheet(context, candidates: selected);
    if (!mounted) return;
    if (outcome == null || outcome == PlaceMergeOutcome.cancelled) return;
    _exitSelection();
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
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaceTile({
    required this.place,
    required this.count,
    this.dragIndex,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final tile = Card.filled(
      margin: const .symmetric(vertical: 4),
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: ListTile(
        selected: selected,
        onTap: selecting ? onToggle : onEdit,
        leading: PlaceBadge(place: place),
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
        trailing: selecting
            ? Padding(
                padding: const .all(12),
                child: Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              )
            : Row(
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
    if (selecting) return tile;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );
  }
}
