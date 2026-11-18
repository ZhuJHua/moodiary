import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

class CategoryPickerSheet extends ConsumerWidget {
  final String? currentCategoryId;

  const CategoryPickerSheet({super.key, required this.currentCategoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryDiaryCountsProvider).value;
    final async = ref.watch(orderedCategoriesProvider);
    if (!async.hasValue) {
      return MSheetScaffold<MetaPickerResult<Category?>>(
        title: context.l10n.editor.pickCategory,
        icon: LucideIcons.folder,
        actions: [MAction(label: context.l10n.common.cancel)],
        child: async.buildLoading(data: (_) => const SizedBox.shrink()),
      );
    }
    return async.buildLoading(
      data: (categories) {
        final options = <MSheetOption<Category?>>[];
        Category? selected;
        for (final category in <Category?>[null, ...categories]) {
          if (category?.id == currentCategoryId) selected = category;
          final count = counts == null
              ? null
              : category == null
              ? counts.total -
                    counts.byCategory.values.fold(
                      0,
                      (sum, value) => sum + value,
                    )
              : counts.byCategory[category.id] ?? 0;
          options.add(
            MSheetOption(
              value: category,
              label: category?.categoryName ?? context.l10n.editor.noCategory,
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: category == null
                      ? null
                      : categoryColorOf(
                          id: category.id,
                          colorValue: category.color,
                        ),
                  border: category == null
                      ? Border.all(
                          color: context.theme.colors.outline,
                          width: 1.4,
                        )
                      : null,
                ),
              ),
              subtitle: count == null
                  ? null
                  : count > 0
                  ? context.l10n.diary.categoryDiaryCount(count: count)
                  : context.l10n.diary.categoryNoDiary,
            ),
          );
        }
        return MetaPickerSheet<Category?>.list(
          title: context.l10n.editor.pickCategory,
          subtitle: context.l10n.editor.categoryPickerSubtitle,
          icon: LucideIcons.folder,
          searchHint: context.l10n.diary.categorySearchHint,
          matchesLabel: (count) =>
              context.l10n.editor.pickerMatches(count: count),
          createLabel: (name) => context.l10n.editor.createCategory(name: name),
          options: options,
          selected: selected,
        );
      },
    );
  }

  static Future<(bool, Category?)> show({
    required BuildContext context,
    required String? currentCategoryId,
  }) async {
    final result = await MSheet.show<MetaPickerResult<Category?>>(
      context,
      builder: (_) => CategoryPickerSheet(currentCategoryId: currentCategoryId),
    );
    if (result == null) return (false, null);
    if (result.created.isNotEmpty) {
      if (!context.mounted) return (false, null);
      final category = Category.create(categoryName: result.created.single);
      final saved = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(categoryControllerProvider.notifier).upsertCategory(category);
      if (!saved) toast.error(message: l10n.diary.categoryCreateFailed);
      return saved ? (true, category) : (false, null);
    }
    final category = result.selected.single;
    return category?.id == currentCategoryId ? (false, null) : (true, category);
  }
}
