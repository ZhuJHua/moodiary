import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 首页分类筛选条：可横滚的无边框 stadium 胶囊行（首个 =「全部」，分类胶囊带色点，
/// 选中态用分类色淡染底色），行尾固定的切换面板入口（有新分类正在同步时挂 Badge）。
/// 顺序消费 [orderedCategoriesProvider]（顺序即置顶）。无分类且无在途同步时整条隐藏；
/// 加载中渲染骨架胶囊。
class CategoryFilterBar extends ConsumerStatefulWidget {
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onOpenSwitcher;

  const CategoryFilterBar({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.onOpenSwitcher,
  });

  @override
  ConsumerState<CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends ConsumerState<CategoryFilterBar> {
  final Map<String?, GlobalKey> _chipKeys = {};

  @override
  void didUpdateWidget(covariant CategoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 覆盖面板返回等外部选中来源：把选中胶囊滚入视野。
    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  void _revealSelected() {
    if (!mounted) return;
    final chipContext = _chipKeys[widget.selectedId]?.currentContext;
    if (chipContext == null) return;
    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderedCategoriesProvider);
    if (async.isLoading && !async.hasValue) {
      return SizedBox(height: 32, child: _Skeleton());
    }
    final categories = async.value ?? const <Category>[];
    final ids = {for (final c in categories) c.id};
    _chipKeys.removeWhere((id, _) => id != null && !ids.contains(id));
    return ValueListenableBuilder(
      valueListenable: SyncPendingTracker.instance.listenable,
      builder: (context, pending, _) {
        // 无分类且无在途新分类 → 整条隐藏；有在途 → 保留入口（Badge），
        // 首次同步 / 换机恢复时首页仍能感知并打开面板看占位。
        if (categories.isEmpty && pending.newCategoryIds.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 32,
          child: _buildBar(context, categories, pending),
        );
      },
    );
  }

  Widget _buildBar(
    BuildContext context,
    List<Category> categories,
    SyncPendingState pending,
  ) {
    final scheme = context.colorScheme;
    final surface = scheme.surface;
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Center(child: _chip(context, null, context.l10n.categoryAll)),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    Center(
                      child: _chip(
                        context,
                        c.id,
                        c.categoryName,
                        color: categoryColorOf(colorValue: c.color, id: c.id),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                ],
              ),
              // 右缘渐隐，暗示可横滚。
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [surface.withValues(alpha: 0), surface],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: '全部分类',
            onPressed: widget.onOpenSwitcher,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh,
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Badge(
              isLabelVisible: pending.newCategoryIds.isNotEmpty,
              smallSize: 8,
              child: const Icon(Icons.segment_rounded, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  /// 无边框 stadium 胶囊。未选中 = 软灰底 + 色点；选中 = 分类色淡染底 + 同色文字
  /// （「全部」无色点，选中走 secondaryContainer）。选中态不打勾，由填充色表达。
  Widget _chip(BuildContext context, String? id, String label, {Color? color}) {
    final key = _chipKeys.putIfAbsent(id, GlobalKey.new);
    final scheme = context.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.selectedId == id;

    final Color bg;
    final Color fg;
    if (!selected) {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else if (color == null) {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    } else {
      bg = Color.alphaBlend(
        color.withValues(alpha: dark ? 0.30 : 0.16),
        scheme.surfaceContainerHigh,
      );
      fg = Color.lerp(color, dark ? Colors.white : Colors.black, 0.35)!;
    }

    return KeyedSubtree(
      key: key,
      child: AnimatedContainer(
        duration: Durations.short4,
        curve: Curves.easeOut,
        height: 32,
        decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelected(id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (color != null) ...[
                    AnimatedContainer(
                      duration: Durations.short4,
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: AnimatedDefaultTextStyle(
                      duration: Durations.short4,
                      style: (context.textTheme.labelMedium ?? const TextStyle())
                          .copyWith(
                            color: fg,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.surfaceContainerHigh;
    Widget pill(double width) => Container(
      width: width,
      height: 32,
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(spacing: 8, children: [pill(64), pill(88), pill(72)]),
    );
  }
}
