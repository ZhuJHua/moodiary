import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 分类选择 sheet：返回选择的 [Category?]，`null` 代表「不分类」。
class CategoryPickerSheet extends ConsumerWidget {
  final String? currentCategoryId;

  const CategoryPickerSheet({super.key, required this.currentCategoryId});

  /// 点已选中的那一项按「没选」返回：调用方拿到结果就会改脏日记、刷新 lastModified
  /// 并在下次同步推上去。改前用的 RadioListTile 在这种情况下是彻底的 no-op。
  void _pick(BuildContext context, Category? category) {
    final changed = category?.id != currentCategoryId;
    Navigator.of(
      context,
    ).pop<_PickerResult>(_PickerResult(category: category, hasResult: changed));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderedCategoriesProvider);
    return MSheetScaffold<_PickerResult>(
      title: '选择分类',
      icon: LucideIcons.folder,
      actions: [MAction(label: context.l10n.common.cancel)],
      child: async.buildLoading(
        data: (categories) => Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            MSheetOptionTile<String?>(
              option: const MSheetOption<String?>(value: null, label: '不分类'),
              selected: currentCategoryId == null,
              onTap: () => _pick(context, null),
            ),
            for (final c in categories)
              MSheetOptionTile<String?>(
                option: MSheetOption<String?>(
                  value: c.id,
                  label: c.categoryName,
                ),
                selected: currentCategoryId == c.id,
                onTap: () => _pick(context, c),
              ),
          ],
        ),
      ),
    );
  }

  /// 调用入口：返回 `(true, Category?)` 表示用户做出了选择；`null` 表示用户没选。
  static Future<(bool, Category?)> show({
    required BuildContext context,
    required String? currentCategoryId,
  }) async {
    final result = await MSheet.show<_PickerResult>(
      context,
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
