import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:mui/mui.dart';

class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final running = status.isRunning;
    return IconButton(
      tooltip: running
          ? context.l10n.sync.statusRunning
          : context.l10n.sync.consoleTitle,
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
      onPressed: () => const SyncLogRoute().push(context),
    );
  }
}
