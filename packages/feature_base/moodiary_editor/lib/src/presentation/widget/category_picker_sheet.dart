import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

class CategoryPickerSheet extends ConsumerWidget {
  final String? currentCategoryId;

  const CategoryPickerSheet({super.key, required this.currentCategoryId});

  Future<Category?> _create(
    BuildContext context,
    WidgetRef ref,
    String query,
  ) async {
    final draft = await showCategoryEditor(
      context,
      initialName: query,
      initialColor: null,
    );
    if (draft == null || !context.mounted) return null;
    final category = Category.create(
      categoryName: draft.name,
      color: draft.color,
    );
    final saved = await ref
        .read(categoryControllerProvider.notifier)
        .upsertCategory(category);
    if (!saved) toast.error(message: l10n.diary.categoryCreateFailed);
    return saved ? category : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderedCategoriesProvider);
    if (!async.hasValue) {
      return MSheetScaffold<List<Category?>>(
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
          options.add(
            MSheetOption(
              value: category,
              label: category?.categoryName ?? context.l10n.editor.noCategory,
              leading: Container(
                width: 10,
                height: 10,
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
            ),
          );
        }
        return MetaPickerSheet<Category?>.single(
          chipSize: .medium,
          title: context.l10n.editor.pickCategory,
          subtitle: context.l10n.editor.categoryPickerSubtitle,
          icon: LucideIcons.folder,
          searchHint: context.l10n.diary.categorySearchHint,
          matchesLabel: (count) =>
              context.l10n.editor.pickerMatches(count: count),
          createLabel: context.l10n.diary.categoryNew,
          onCreate: (query) => _create(context, ref, query),
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
    final result = await MSheet.show<List<Category?>>(
      context,
      builder: (_) => CategoryPickerSheet(currentCategoryId: currentCategoryId),
    );
    if (result == null) return (false, null);
    final category = result.single;
    return category?.id == currentCategoryId ? (false, null) : (true, category);
  }
}
