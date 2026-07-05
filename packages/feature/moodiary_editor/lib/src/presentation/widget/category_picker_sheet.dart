import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_data/moodiary_data.dart';

/// 分类选择 sheet：返回选择的 [Category?]，`null` 代表「不分类」。
class CategoryPickerSheet extends ConsumerWidget {
  final String? currentCategoryId;

  const CategoryPickerSheet({super.key, required this.currentCategoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderedCategoriesProvider);
    return SafeArea(
      child: async.buildLoading(
        data: (categories) {
          return RadioGroup<String?>(
            groupValue: currentCategoryId,
            onChanged: (selected) {
              // selected 必来自下面某个 RadioListTile，firstWhere 不会抛，无需 orElse。
              final cat = selected == null
                  ? null
                  : categories.firstWhere((c) => c.id == selected);
              Navigator.of(context).pop<_PickerResult>(
                _PickerResult(category: cat, hasResult: true),
              );
            },
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const RadioListTile<String?>(
                  value: null,
                  title: Text('不分类'),
                ),
                const Divider(height: 0),
                for (final c in categories)
                  RadioListTile<String?>(
                    value: c.id,
                    title: Text(c.categoryName),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 调用入口：返回 `(true, Category?)` 表示用户做出了选择；`null` 表示用户没选。
  static Future<(bool, Category?)> show({
    required BuildContext context,
    required String? currentCategoryId,
  }) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => CategoryPickerSheet(currentCategoryId: currentCategoryId),
    );
    if (result == null || !result.hasResult) return (false, null);
    return (true, result.category);
  }
}

class _PickerResult {
  final Category? category;
  final bool hasResult;
  const _PickerResult({required this.category, required this.hasResult});
}
