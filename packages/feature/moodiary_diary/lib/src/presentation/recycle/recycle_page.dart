import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class RecyclePage extends ConsumerWidget {
  const RecyclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recycleBinDiariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diary.recycleTitle),
        actions: [
          async.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: context.l10n.diary.recycleClear,
                    icon: const Icon(LucideIcons.eraser),
                    onPressed: () => _onClear(context, ref, list.length),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.buildLoading(
        data: (diaries) {
          if (diaries.isEmpty) {
            return _Empty();
          }
          return ListView.separated(
            padding: const .all(12),
            itemBuilder: (context, index) {
              final diary = diaries[index];
              return _RecycleTile(
                diary: diary,
                onRestore: () => _onRestore(context, ref, diary),
                onDelete: () => _onPermanentDelete(context, ref, diary),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: diaries.length,
          );
        },
      ),
    );
  }

  Future<void> _onRestore(
    BuildContext context,
    WidgetRef ref,
    Diary diary,
  ) async {
    final ok = await ref
        .read(recycleBinDiariesProvider.notifier)
        .restore(diary);
    if (ok) {
      toast.success(message: l10n.diary.recycleRestored);
    } else {
      toast.error(message: l10n.diary.recycleRestoreFailed);
    }
  }

  Future<void> _onPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    Diary diary,
  ) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.recyclePurgeTitle,
      message: l10n.diary.recyclePurgeMessage,
      confirmLabel: l10n.diary.recyclePurgeConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    final ok = await ref
        .read(recycleBinDiariesProvider.notifier)
        .permanentDelete(diary.isarId);
    if (ok) {
      toast.success(message: l10n.diary.recyclePurged);
    } else {
      toast.error(message: l10n.diary.recyclePurgeFailed);
    }
  }

  Future<void> _onClear(BuildContext context, WidgetRef ref, int total) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.recycleClearTitle,
      message: l10n.diary.recycleClearMessage(count: total),
      confirmLabel: l10n.diary.recycleClearConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    final count = await ref.read(recycleBinDiariesProvider.notifier).clear();
    toast.success(message: l10n.diary.recycleCleared(count: count));
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.trash2,
            size: 48,
            color: context.theme.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.diary.recycleEmpty,
            style: context.theme.typography.titleMedium.onSurface,
          ),
        ],
      ),
    );
  }
}

class _RecycleTile extends StatelessWidget {
  final Diary diary;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _RecycleTile({
    required this.diary,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return Card(
      margin: .zero,
      child: Padding(
        padding: const .all(12),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              diary.title.isEmpty ? context.l10n.common.untitled : diary.title,
              style: typo.titleMedium.onSurface,
              maxLines: 1,
              overflow: .ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              TimeFormat.listDateTime(diary.time),
              style: typo.labelSmall.onSurfaceVariant,
            ),
            if (diary.contentText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                diary.contentText.trim(),
                style: typo.bodyMedium.onSurface,
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: .end,
              children: [
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(LucideIcons.undo2),
                  label: Text(context.l10n.diary.recycleRestore),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(LucideIcons.trash2),
                  label: Text(context.l10n.diary.recyclePurgeConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
