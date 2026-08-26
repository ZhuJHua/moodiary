import 'package:moodiary_sync/src/data/incremental_engine.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 云后端共用的编排样板：isReady 检查 + 交给增量引擎。
/// 各后端只差一句配置错误文案（[notReadyError]），三个入口不必各抄三遍。
mixin CloudSyncOrchestration implements IRemoteSyncBackend {
  /// isReady 为假时抛的配置错误（各后端文案不同）。
  SyncException get notReadyError;

  @override
  Future<SyncReport> pushAll() async {
    if (!isReady) throw notReadyError;
    return IncrementalSyncEngine(this).push();
  }

  @override
  Future<SyncReport> pullAll() async {
    if (!isReady) throw notReadyError;
    return IncrementalSyncEngine(this).pull();
  }

  @override
  Future<SyncReport> syncAll() async {
    if (!isReady) throw notReadyError;
    return IncrementalSyncEngine(this).sync();
  }
}
