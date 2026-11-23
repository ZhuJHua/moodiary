import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../../application/diary_filter.dart';
import '../../application/diary_selection.dart';

class TagManagerPage extends ConsumerStatefulWidget {
  const TagManagerPage({super.key, this.manageOnly = false});

  factory TagManagerPage.fromRoute(GoRouterState state) =>
      TagManagerPage(manageOnly: state.params['manage_only'] as bool? ?? false);

  final bool manageOnly;

  @override
  ConsumerState<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends ConsumerState<TagManagerPage> {
  late final _repo = getIt<TagRepository>();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(tagCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diary.tagManagerTitle)),
      floatingActionButton: catalog.value?.usage.isNotEmpty == true
          ? FloatingActionButton(
              heroTag: 'tagManagerFab',
              onPressed: () => _edit(),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: catalog.buildLoading(
        data: (catalog) {
          if (catalog.usage.isEmpty) {
            // 空态没有搜索框，留着旧关键词会让新建的标签被过滤掉。
            _query = '';
            return Center(
              child: Column(
                mainAxisSize: .min,
                children: [
                  Icon(
                    LucideIcons.hash,
                    size: 48,
                    color: context.theme.colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.diary.tagEmpty,
                    style: context.theme.typography.titleMedium.onSurface,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(LucideIcons.plus),
                    label: Text(context.l10n.diary.tagNew),
                  ),
                ],
              ),
            );
          }
          final tags = catalog.usage
              .where((tag) => tag.name.toLowerCase().contains(_query))
              .toList();
          final dates = DateFormat.MMMd(
            Localizations.localeOf(context).toLanguageTag(),
          );
          return Column(
            children: [
              Padding(
                padding: const .fromLTRB(12, 12, 12, 6),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  textInputAction: .search,
                  decoration: InputDecoration(
                    hintText: context.l10n.diary.tagSearchHint,
                    prefixIcon: const Icon(LucideIcons.search),
                    filled: true,
                    isDense: true,
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.mediumBorderRadius,
                      borderSide: .none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: tags.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.diary.tagNoMatch,
                          style: context
                              .theme
                              .typography
                              .bodyMedium
                              .onSurfaceVariant,
                        ),
                      )
                    : ListView.builder(
                        padding: const .fromLTRB(12, 4, 12, 88),
                        itemCount: tags.length,
                        itemBuilder: (context, index) =>
                            _tile(tags[index], dates),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(TagUsage tag, DateFormat dates) {
    final colors = context.theme.colors;
    return MetaTile<String>(
      leading: MetaBadge(
        icon: LucideIcons.hash,
        background: tag.count == 0
            ? colors.surfaceContainerHighest
            : colors.secondaryContainer,
        foreground: tag.count == 0
            ? colors.outline
            : colors.onSecondaryContainer,
      ),
      title: tag.name,
      subtitle: tag.lastUsed == null
          ? context.l10n.diary.categoryNoDiary
          : context.l10n.diary.tagUsage(
              count: tag.count,
              date: dates.format(tag.lastUsed!.toLocal()),
            ),
      onTap: widget.manageOnly
          ? null
          : () {
              ref.read(homeDiaryFilterProvider.notifier).select(.tag(tag.name));
              ref.read(diarySelectionProvider.notifier).clear();
              Navigator.of(context).pop();
            },
      entries: [
        MMenuEntry(
          value: 'rename',
          label: context.l10n.diary.rename,
          icon: LucideIcons.squarePen,
        ),
        MMenuEntry(
          value: 'delete',
          label: context.l10n.common.delete,
          icon: LucideIcons.trash2,
          isDestructive: true,
        ),
      ],
      onSelected: (key) => key == 'rename' ? _edit(tag) : _delete(tag),
    );
  }

  Future<void> _edit([TagUsage? source]) async {
    final input = await MAlert.prompt(
      context,
      title: source == null ? l10n.diary.tagNew : l10n.diary.rename,
      initialValue: source?.name,
      validator: (value) =>
          Tag.normalize(value) == null ? l10n.diary.tagNameEmpty : null,
    );
    final name = Tag.normalize(input ?? '');
    if (!mounted || name == null || name == source?.name) return;
    final failure = source == null
        ? l10n.diary.categoryCreateFailed
        : l10n.diary.categoryRenameFailed;
    try {
      final usage = await _repo.getTagUsage();
      if (!mounted) return;
      final exists = usage.any((tag) => tag.name == name);
      if (source == null) {
        if (exists) {
          toast.info(message: l10n.diary.tagExists);
          return;
        }
        await _repo.ensureTags([name]);
        if (mounted) {
          toast.success(message: l10n.diary.categoryCreated(name: name));
        }
        return;
      }
      if (exists) {
        final confirmed = await MAlert.confirm(
          context,
          title: l10n.diary.tagMergeTitle,
          message: l10n.diary.tagMergeMessage(
            source: source.name,
            target: name,
            count:
                usage
                    .where((tag) => tag.name == source.name)
                    .firstOrNull
                    ?.count ??
                0,
          ),
          confirmLabel: l10n.diary.placeMerge,
        );
        if (!confirmed || !mounted) return;
      }
      final changed = await _repo.renameTag(source.name, name);
      if (!mounted) return;
      if (changed == 0) {
        toast.error(message: failure);
        return;
      }
      if (ref.read(homeDiaryFilterProvider).tagName == source.name) {
        ref.read(homeDiaryFilterProvider.notifier).select(.tag(name));
      }
      toast.success(message: l10n.diary.categoryRenamed(name: name));
    } catch (error, stack) {
      logger.e('Save tag failed', error: error, stackTrace: stack);
      if (mounted) toast.error(message: failure);
    }
  }

  Future<void> _delete(TagUsage tag) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.tagDeleteTitle,
      message: tag.count == 0
          ? l10n.diary.tagDeleteUnused
          : l10n.diary.tagDeleteMessage(count: tag.count, name: tag.name),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      final changed = await _repo.deleteTag(tag.name);
      if (!mounted) return;
      if (changed == 0) {
        toast.error(message: l10n.diary.recyclePurgeFailed);
      } else {
        toast.success(message: l10n.diary.categoryDeleted);
      }
    } catch (error, stack) {
      logger.e('Delete tag failed', error: error, stackTrace: stack);
      if (mounted) toast.error(message: l10n.diary.recyclePurgeFailed);
    }
  }
}
