import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_status_sheet.dart';

/// AppBar 同步入口：自监听 [syncControllerProvider]，运行中转圈，点击弹出状态面板。
/// 供两端 app 直接 `const SyncStatusButton()` 组合，无需宿主接线。
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(syncControllerProvider) is SyncRunning;
    return IconButton(
      tooltip: running ? '正在同步' : '同步状态',
      icon: running
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
      onPressed: () => showSyncStatusSheet(context),
    );
  }
}
