import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  late final SyncRunner _runner = getIt<SyncRunner>();

  @override
  SyncState build() {
    final status = _runner.status;
    void mirror() {
      final running = status.value.running;
      final current = state;
      if (running != null &&
          running.trigger != .manual &&
          current is SyncIdle) {
        state = .syncing(
          label: l10n.sync.syncingAuto(backend: running.backendName),
          auto: true,
        );
      } else if (running == null && current is SyncRunning && current.auto) {
        state = const .idle();
      }
    }

    status.addListener(mirror);
    ref.onDispose(() => status.removeListener(mirror));
    return const .idle();
  }

  Future<void> push(IRemoteSyncBackend backend) =>
      _run(.push, l10n.sync.uploading(backend: backend.displayName));

  Future<void> pull(IRemoteSyncBackend backend) =>
      _run(.pull, l10n.sync.downloading(backend: backend.displayName));

  Future<void> sync(IRemoteSyncBackend backend) =>
      _run(.sync, l10n.sync.syncing(backend: backend.displayName));

  Future<void> _run(SyncDirection direction, String label) async {
    state = .syncing(label: label);
    final outcome = await _runner.run(direction, trigger: .manual);
    if (outcome == null) {
      state = const .idle();
      return;
    }
    _settle(outcome);
  }

  void _settle(SyncOutcome outcome) {
    state = switch (outcome.kind) {
      .failed => .error(message: outcome.message),
      .partial || .stopped => .partial(message: outcome.message),
      .changed => .success(message: outcome.message),
      .upToDate => .success(message: outcome.message, upToDate: true),
    };
  }

  void stop() => _runner.stop();

  void reset() => state = const .idle();
}

sealed class SyncState {
  const SyncState();
  const factory SyncState.idle() = SyncIdle;
  const factory SyncState.syncing({required String label, bool auto}) =
      SyncRunning;
  const factory SyncState.success({required String message, bool upToDate}) =
      SyncSuccess;
  const factory SyncState.partial({required String message}) = SyncPartial;
  const factory SyncState.error({required String message}) = SyncError;
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncRunning extends SyncState {
  final String label;

  final bool auto;
  const SyncRunning({required this.label, this.auto = false});
}

class SyncSuccess extends SyncState {
  final String message;

  final bool upToDate;
  const SyncSuccess({required this.message, this.upToDate = false});
}

class SyncPartial extends SyncState {
  final String message;
  const SyncPartial({required this.message});
}

class SyncError extends SyncState {
  final String message;
  const SyncError({required this.message});
}
