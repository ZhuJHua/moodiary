import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 首页分类筛选条：在共享的 [MoodiaryChipBar] 之上叠加分类数据加载、骨架屏、
/// 以及带「未同步」角标的分类切换器按钮。
class CategoryFilterBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderedCategoriesProvider);
    if (async.isLoading && !async.hasValue) {
      return SizedBox(height: 32, child: _Skeleton());
    }
    final categories = async.value ?? const <Category>[];
    return ValueListenableBuilder(
      valueListenable: SyncPendingTracker.instance.listenable,
      builder: (context, pending, _) {
        if (categories.isEmpty && pending.newCategoryIds.isEmpty) {
          return const SizedBox.shrink();
        }
        return MoodiaryChipBar<String?>(
          selected: selectedId,
          onSelected: onSelected,
          items: [
            MoodiaryChipData(value: null, label: context.l10n.categoryAll),
            for (final c in categories)
              MoodiaryChipData(
                value: c.id,
                label: c.categoryName,
                accentColor: categoryColorOf(colorValue: c.color, id: c.id),
              ),
          ],
          trailing: _SwitcherButton(
            onOpenSwitcher: onOpenSwitcher,
            hasPending: pending.newCategoryIds.isNotEmpty,
          ),
        );
      },
    );
  }
}

class _SwitcherButton extends StatelessWidget {
  final VoidCallback onOpenSwitcher;
  final bool hasPending;

  const _SwitcherButton({required this.onOpenSwitcher, required this.hasPending});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        tooltip: context.l10n.categoryAllCategory,
        onPressed: onOpenSwitcher,
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Badge(
          isLabelVisible: hasPending,
          smallSize: 8,
          child: const Icon(Icons.segment_rounded, size: 18),
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
