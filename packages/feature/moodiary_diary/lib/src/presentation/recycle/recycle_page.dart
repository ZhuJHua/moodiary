import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';

class RecyclePage extends ConsumerWidget {
  const RecyclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recycleBinDiariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          async.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空回收站',
                    icon: const Icon(Icons.delete_sweep_outlined),
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
            padding: const EdgeInsets.all(12),
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
    final ok = await ref.read(recycleBinDiariesProvider.notifier).restore(diary);
    if (ok) {
      toast.success(message: '已恢复');
    } else {
      toast.error(message: '恢复失败');
    }
  }

  Future<void> _onPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    Diary diary,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '彻底删除？',
      message: '此操作不可恢复，日记将永久消失。',
      confirmLabel: '彻底删除',
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(recycleBinDiariesProvider.notifier)
        .permanentDelete(diary.isarId);
    if (ok) {
      toast.success(message: '已永久删除');
    } else {
      toast.error(message: '删除失败');
    }
  }

  Future<void> _onClear(
    BuildContext context,
    WidgetRef ref,
    int total,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '清空回收站？',
      message: '将永久删除 $total 条日记。此操作不可恢复。',
      confirmLabel: '清空',
    );
    if (confirmed != true) return;
    final count = await ref.read(recycleBinDiariesProvider.notifier).clear();
    toast.success(message: '已清空 $count 条');
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            '回收站为空',
            style: Theme.of(context).textTheme.titleMedium,
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
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diary.title.isEmpty ? '(无标题)' : diary.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              TimeUtil.listDateTime(diary.time),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (diary.contentText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                diary.contentText.trim(),
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('彻底删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
