import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

class CategoryPickerSheet extends ConsumerWidget {
  final String? currentCategoryId;

  const CategoryPickerSheet({super.key, required this.currentCategoryId});

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
      title: context.l10n.editor.pickCategory,
      icon: LucideIcons.folder,
      actions: [MAction(label: context.l10n.common.cancel)],
      child: async.buildLoading(
        data: (categories) => Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            MSheetOptionTile<String?>(
              option: MSheetOption<String?>(
                value: null,
                label: context.l10n.editor.noCategory,
              ),
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
