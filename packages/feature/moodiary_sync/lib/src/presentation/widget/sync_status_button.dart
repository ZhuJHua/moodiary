import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_status_sheet.dart';
import 'package:mui/mui.dart';

/// AppBar 同步入口：运行中（手动或自动）转圈，连接健康坏了右上角一枚 error 色小点，
/// 点击弹出状态面板。供两端 app 直接 `const SyncStatusButton()` 组合，无需宿主接线。
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(syncControllerProvider) is SyncRunning;
    return ValueListenableBuilder(
      valueListenable: getIt<SyncRunner>().status,
      builder: (context, status, _) => IconButton(
        tooltip: running
            ? context.l10n.sync.statusRunning
            : context.l10n.sync.statusTitle,
        icon: running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Badge(
                isLabelVisible: status.health.isBad,
                smallSize: 7,
                backgroundColor: context.theme.colors.error,
                child: const Icon(LucideIcons.refreshCw),
              ),
        onPressed: () => showSyncStatusSheet(context),
      ),
    );
  }
}
