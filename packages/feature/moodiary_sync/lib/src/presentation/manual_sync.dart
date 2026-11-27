import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/sync_controller.dart';
import '../application/sync_runner.dart';
import '../data/sync.dart';
import '../data/sync_data_providers.dart';
import 'widget/sync_key_guard.dart';

part 'manual_sync.g.dart';

@Riverpod(keepAlive: true)
Future<bool> Function() syncOnlineCheck(Ref ref) =>
    NetworkStatus.isNetworkConnected;

sealed class ManualSyncResult {
  const ManualSyncResult();
}

final class ManualSyncCompleted extends ManualSyncResult {
  const ManualSyncCompleted(this.outcome);
  final SyncOutcome outcome;
}

final class ManualSyncBusy extends ManualSyncResult {
  const ManualSyncBusy();
}

final class ManualSyncCancelled extends ManualSyncResult {
  const ManualSyncCancelled();
}

final class ManualSyncUnreachable extends ManualSyncResult {
  const ManualSyncUnreachable();
}

final class ManualSyncFailed extends ManualSyncResult {
  const ManualSyncFailed(this.error);
  final Object error;
}

Future<ManualSyncResult> triggerManualSync({
  required BuildContext context,
  required WidgetRef ref,
  bool Function()? canPrompt,
  Future<bool> Function()? isOnline,
  Duration unreachableProbeTimeout = const Duration(seconds: 3),
}) async {
  final guard = ref.read(syncOperationGuardProvider);
  if (guard.isBusy) return const ManualSyncBusy();
  var entered = false;
  try {
    final checkOnline =
        isOnline ?? ref.read<Future<bool> Function()>(syncOnlineCheckProvider);
    final online = await checkOnline();
    if (guard.isBusy) return const ManualSyncBusy();
    if (!context.mounted) return const ManualSyncCancelled();
    final controller = ref.read(syncControllerProvider.notifier);
    if (!online) {
      controller.markUnreachable();
      return const ManualSyncUnreachable();
    }

    final result = await controller.sync(
      prepare: (operation, backend) async {
        entered = true;
        if (!context.mounted || canPrompt?.call() == false) return false;
        final unreachable =
            ref.read(syncControllerProvider).health == .unreachable;
        return ensureSyncKeyReady(
          context: context,
          ref: ref,
          operation: operation,
          backend: backend,
          canPrompt: canPrompt,
          manifestTimeout: unreachable ? unreachableProbeTimeout : null,
        );
      },
    );
    if (result != null) return ManualSyncCompleted(result);
    return entered ? const ManualSyncCancelled() : const ManualSyncBusy();
  } on SyncException catch (error) {
    return error.kind.isUnreachable
        ? const ManualSyncUnreachable()
        : ManualSyncFailed(error);
  } catch (error) {
    return ManualSyncFailed(error);
  }
}
