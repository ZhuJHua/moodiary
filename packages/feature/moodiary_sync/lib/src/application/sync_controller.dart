import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

/// 同步状态的 Riverpod 桥：idle → syncing → success / partial / error。执行本身在
/// [SyncRunner]；这里只是把它的 [SyncStatus] 折成 widget 好消费的五态。
///
/// 自动同步（watcher 经 runner 跑的）只镜像 **running**：图标要转、弹窗要显示进度、
/// 设置页要能停；但它的结果不进 success / error——那会让设置页每 30 秒弹一次
/// 「已是最新」。自动同步的结果由弹窗直接读 `runner.status.last`。
///
/// keepAlive：同步是后台过程，不随页面销毁。
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

  /// 双向同步（pull 后 push，云后端专用）。引擎侧在同一把锁内原子完成。
  Future<void> sync(IRemoteSyncBackend backend) =>
      _run(.sync, l10n.sync.syncing(backend: backend.displayName));

  Future<void> _run(SyncDirection direction, String label) async {
    state = .syncing(label: label);
    final outcome = await _runner.run(direction, trigger: .manual);
    if (outcome == null) {
      // 撞上了正在跑的自动同步：交给镜像逻辑接管显示。
      state = const .idle();
      return;
    }
    _settle(outcome);
  }

  /// 报告落地。**有失败条目或被用户停止就不是 success**：绿勾配「同步完成」会让用户
  /// 以为云端已有完整副本，而引擎恰恰因为这两种情况不推进「上次同步时间」。
  void _settle(SyncOutcome outcome) {
    state = switch (outcome.kind) {
      .failed => .error(message: outcome.message),
      .partial || .stopped => .partial(message: outcome.message),
      .changed => .success(message: outcome.message),
      .upToDate => .success(message: outcome.message, upToDate: true),
    };
  }

  /// 请求停止当前同步（协作式：不再发起新条目，在飞的跑完后正常收尾）。
  /// 状态仍保持 syncing，直到引擎返回报告。
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

  /// 由 watcher 发起（变更 / 关闭日记 / 轮询 / 回前台 / 网络恢复），不是用户手点。
  final bool auto;
  const SyncRunning({required this.label, this.auto = false});
}

class SyncSuccess extends SyncState {
  final String message;

  /// 跑完了但两侧都没动：标题说「已是最新」而不是「同步完成」。
  final bool upToDate;
  const SyncSuccess({required this.message, this.upToDate = false});
}

/// 跑完了但不完整：有条目失败，或被用户停止。
class SyncPartial extends SyncState {
  final String message;
  const SyncPartial({required this.message});
}

class SyncError extends SyncState {
  final String message;
  const SyncError({required this.message});
}
