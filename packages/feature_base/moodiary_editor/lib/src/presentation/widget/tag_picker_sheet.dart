import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';

@visibleForTesting
({List<String> retained, List<String> addedNames}) tagSelectionDiff(
  List<String> tagIds,
  Map<String, Tag> byId,
  MetaPickerResult<String> result,
) {
  final original = resolveTagNames(tagIds, byId).map((tag) => tag.name).toSet();
  final selected = {...result.selected, ...result.created};
  return (
    retained: [
      for (final id in tagIds)
        if (byId[id]?.deleted != false || selected.contains(byId[id]?.name)) id,
    ],
    addedNames: selected.difference(original).toList(),
  );
}

@visibleForTesting
List<String>? applyTagSelection(
  List<String> original,
  List<String> retained,
  List<String> ensured,
) {
  final seen = retained.toSet();
  final next = [...retained, ...ensured.where(seen.add)];
  return listEquals(original, next) ? null : next;
}

abstract final class TagPickerSheet {
  static Future<({Map<String, Tag> byId, List<TagUsage> usage})?> _catalog(
    BuildContext context,
  ) async {
    try {
      return await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(tagCatalogProvider.future);
    } catch (e, s) {
      logger.e('tag catalog failed', error: e, stackTrace: s);
      toast.error(message: l10n.common.loadFailed);
      return null;
    }
  }

  static Future<(bool, String?)> pickOne(
    BuildContext context, {
    String? current,
  }) async {
    final catalog = await _catalog(context);
    if (catalog == null || !context.mounted) return (false, null);
    const icon = Icon(LucideIcons.hash, size: 18);
    final result = await MSheet.show<MetaPickerResult<String?>>(
      context,
      builder: (context) => MetaPickerSheet<String?>.list(
        title: context.l10n.editor.pickTags,
        subtitle: null,
        icon: LucideIcons.hash,
        searchHint: context.l10n.editor.tagSearchHint,
        matchesLabel: (count) =>
            context.l10n.editor.pickerMatches(count: count),
        selected: current,
        options: [
          MSheetOption(
            value: null,
            label: context.l10n.diary.allTags,
            leading: icon,
          ),
          for (final tag in catalog.usage)
            if (tag.count > 0)
              MSheetOption(
                value: tag.name,
                label: tag.name,
                leading: icon,
                subtitle: context.l10n.diary.searchResult(count: tag.count),
              ),
        ],
      ),
    );
    if (result == null || result.selected.single == current) {
      return (false, null);
    }
    return (true, result.selected.single);
  }

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> tagIds,
  }) async {
    final catalog = await _catalog(context);
    if (catalog == null || !context.mounted) return null;
    final initial = resolveTagNames(
      tagIds,
      catalog.byId,
    ).map((tag) => tag.name).toSet();
    final usage = [...catalog.usage]
      ..sort((first, second) {
        final firstTime = first.lastUsed;
        final secondTime = second.lastUsed;
        if (firstTime == null && secondTime != null) return 1;
        if (firstTime != null && secondTime == null) return -1;
        final recent = firstTime?.compareTo(secondTime!) ?? 0;
        if (recent != 0) return -recent;
        final count = second.count.compareTo(first.count);
        return count != 0 ? count : first.name.compareTo(second.name);
      });
    final names = {...usage.map((tag) => tag.name), ...initial};
    final result = await MSheet.show<MetaPickerResult<String>>(
      context,
      builder: (context) => MetaPickerSheet<String>.wrap(
        title: context.l10n.editor.pickTags,
        selectionSubtitle: (count) =>
            context.l10n.editor.tagPickerSubtitle(count: count),
        icon: LucideIcons.hash,
        searchHint: context.l10n.editor.tagSearchHint,
        matchesLabel: (count) =>
            context.l10n.editor.pickerMatches(count: count),
        selectedLabel: context.l10n.editor.tagSelected,
        recentLabel: context.l10n.editor.tagRecent,
        createLabel: (name) => context.l10n.editor.createTag(name: name),
        createHint: context.l10n.editor.createTagHint,
        normalizeName: Tag.normalize,
        initial: initial,
        options: [
          for (final name in names) MSheetOption(value: name, label: name),
        ],
      ),
    );
    if (result == null) return null;
    final diff = tagSelectionDiff(tagIds, catalog.byId, result);
    final ensured = diff.addedNames.isEmpty
        ? <String>[]
        : await getIt<TagRepository>().ensureTags(diff.addedNames);
    return applyTagSelection(tagIds, diff.retained, ensured);
  }
}
