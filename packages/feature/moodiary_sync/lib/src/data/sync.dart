import 'dart:typed_data';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';

/// 同步 / 备份后端的统一抽象。
///
/// - [SyncBackend]：基础接口（push/pull/显示名/就绪），可用于本地 JSON 文件等非远端实现。
/// - [IRemoteSyncBackend]：云端标记接口，额外提供低层对象原语供引擎做增量同步。
///   get_it 中**同时只注册一个**，由当前 [SyncProviderType] 决定。
abstract class SyncBackend {
  String get displayName;

  /// 是否已就绪可执行 [pushAll]（例如 WebDAV 是否填了 url/user/pass）。
  bool get isReady;

  Future<SyncReport> pushAll();

  Future<SyncReport> pullAll();
}

abstract class IRemoteSyncBackend implements SyncBackend {
  factory IRemoteSyncBackend.get() => getIt<IRemoteSyncBackend>();

  /// 与 KV `syncProvider` 对齐的 provider 类型。
  SyncProviderType get type;

  /// 多后端 tombstone 跟踪用的稳定 ID（[MoodiaryKVs.tombstonePushedBackends]）。
  /// `null` = 不参与跟踪，引擎 push tombstone 完毕即从 Isar 清除。
  String? get persistentBackendId;

  /// 探测连通性 / 凭据。失败返回错误信息，成功返回 `null`。
  Future<String?> testConnection();

  /// 双向同步：同一把锁内先 pull 再 push，原子完成、不与其它操作交叠。
  Future<SyncReport> syncAll();

  /// 读取远端对象，[key] 为相对路径。
  /// 契约（引擎正确性依赖）：**仅**「远端不存在」返回 `null`（引擎据此走首次同步
  /// 分支）；网络/认证/服务器错误必须抛 [SyncException]、不得吞错返回 `null` ——
  /// 否则 push 会把 manifest 从零重建、丢失远端独有条目。
  Future<Uint8List?> readObject(String key);

  /// 写入远端对象。失败抛异常。
  Future<void> writeObject(String key, Uint8List bytes);

  /// 条件创建：仅当对象不存在时写入。`false` = 远端已存在（412），其它错误抛
  /// [SyncException]。原子性取决于服务器对 `If-None-Match: *` 的支持 —— 不支持的
  /// 会覆盖写并返回 `true`，调用方（租约锁）须用「写后回读校验」兜底。
  Future<bool> tryCreateExclusive(String key, Uint8List bytes);

  /// 删除远端对象。「不存在」视为成功静默返回；其它错误必须抛 [SyncException]，
  /// 引擎据此决定 tombstone 是否真的已被远端接收。
  Future<void> deleteObject(String key);

  /// 查询远端对象 Last-Modified（不下载内容）。返回 ISO 8601 字符串，不存在时空字符串。
  Future<String> statObject(String key);
}

class SyncReport {
  final int diaryCount;
  final int categoryCount;
  final Duration elapsed;
  final String? warning;

  /// 失败（已跳过）的条目数。>0 表示同步不完整，引擎不更新「上次同步时间」、下次重试。
  final int failed;

  /// 被用户手动停止（协作式取消，见 `SyncCancellation`）。已完成条目有效，
  /// 未处理的下次继续；同样不更新「上次同步时间」。
  final bool cancelled;

  const SyncReport({
    required this.diaryCount,
    required this.categoryCount,
    required this.elapsed,
    this.warning,
    this.failed = 0,
    this.cancelled = false,
  });

  @override
  String toString() =>
      '日记 $diaryCount 条 / 分类 $categoryCount 条（耗时 ${elapsed.inMilliseconds}ms）'
      '${warning == null ? '' : '\n$warning'}';
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => 'SyncException: $message';
}
