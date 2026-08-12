import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class CacheUsageTile extends ConsumerWidget {
  final bool isFirst;
  final bool isLast;

  const CacheUsageTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    final async = ref.watch(cacheControllerProvider);
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(LucideIcons.brushCleaning, color: scheme.onSurfaceVariant),
      title: '清理缓存',
      trailing: Text(
        async.when(
          data: (u) => u.display,
          loading: () => '...',
          error: (_, _) => '—',
        ),
        style: context.theme.typography.bodySmall.primary,
      ),
      onTap: () => _clear(context, ref),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    await ref.read(cacheControllerProvider.notifier).clear();
    toast.success(message: '清理成功');
  }
}
