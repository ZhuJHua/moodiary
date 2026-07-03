import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

/// 同步 controller：状态机 idle → syncing → idle / error。不持有具体 [SyncBackend]，
/// 调用方在 [push]/[pull] 时显式传入，同一 controller 可服务 JSON 备份与 WebDAV。
///
/// keepAlive：同步是后台过程，不随页面销毁 —— 否则 autoDispose 会在页面关闭时销毁
/// notifier，同步完成后的 state 赋值直接抛错。
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  SyncState build() => const SyncState.idle();

  Future<void> push(SyncBackend backend) async {
    state = SyncState.syncing(label: '上传 / 导出中：${backend.displayName}');
    try {
      final report = await backend.pushAll();
      state = SyncState.success(message: report.toString());
    } on SyncException catch (e) {
      state = SyncState.error(message: e.message);
    } catch (e) {
      state = SyncState.error(message: e.toString());
    }
  }

  Future<void> pull(SyncBackend backend) async {
    state = SyncState.syncing(label: '下载 / 导入中：${backend.displayName}');
    try {
      final report = await backend.pullAll();
      state = SyncState.success(message: report.toString());
    } on SyncException catch (e) {
      state = SyncState.error(message: e.message);
    } catch (e) {
      state = SyncState.error(message: e.toString());
    }
  }

  /// 双向同步（pull 后 push，云后端专用）。引擎侧在同一把锁内原子完成。
  Future<void> sync(IRemoteSyncBackend backend) async {
    state = SyncState.syncing(label: '同步中：${backend.displayName}');
    try {
      final report = await backend.syncAll();
      state = SyncState.success(message: report.toString());
    } on SyncException catch (e) {
      state = SyncState.error(message: e.message);
    } catch (e) {
      state = SyncState.error(message: e.toString());
    }
  }

  /// 请求停止当前同步（协作式：不再发起新条目，在飞的跑完后正常收尾，
  /// 见 [SyncCancellation]）。状态仍保持 syncing，直到引擎返回报告。
  void stop() => SyncCancellation.instance.requestStop();

  void reset() => state = const SyncState.idle();
}

sealed class SyncState {
  const SyncState();
  const factory SyncState.idle() = SyncIdle;
  const factory SyncState.syncing({required String label}) = SyncRunning;
  const factory SyncState.success({required String message}) = SyncSuccess;
  const factory SyncState.error({required String message}) = SyncError;
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncRunning extends SyncState {
  final String label;
  const SyncRunning({required this.label});
}

class SyncSuccess extends SyncState {
  final String message;
  const SyncSuccess({required this.message});
}

class SyncError extends SyncState {
  final String message;
  const SyncError({required this.message});
}
