import 'dart:typed_data';

import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';

/// 同步 / 备份后端的统一抽象，按依赖方向拆三层：
///
/// - [RemoteObjectStore]：对象存储原语。**引擎只依赖它**——归档导入这类「只当
///   对象源用」的实现（LocalArchiveBackend）实现到这一层为止，不必再为
///   push/pull/syncAll 写一排 UnimplementedError。
/// - [SyncBackend]：编排门面（push/pull/显示名/就绪）。
/// - [IRemoteSyncBackend]：云端后端 = 编排 + 对象原语 + provider 元信息。
///   [RemoteSyncRegistry] 中**同时只持有一个**，由当前 [SyncProviderType] 决定。
abstract class SyncBackend {
  String get displayName;

  /// 是否已就绪可执行 [pushAll]（例如 WebDAV 是否填了 url/user/pass）。
  bool get isReady;

  Future<SyncReport> pushAll();

  Future<SyncReport> pullAll();
}

/// 低层对象存储原语。引擎、租约锁、密钥文件管理只认这一层。
abstract class RemoteObjectStore {
  /// 日志用显示名。
  String get displayName;

  /// 多后端 tombstone 跟踪用的稳定 ID（记入 `SyncTombstone.pushedBackends`）。
  /// `null` = 不参与跟踪，引擎 push tombstone 完毕即清除墓碑行。
  String? get persistentBackendId;

  /// 读取远端对象，[key] 为相对路径。
  /// 契约（引擎正确性依赖）：**仅**「远端不存在」返回 `null`（引擎据此走首次同步
  /// 分支）；网络/认证/服务器错误必须抛 [SyncException]、不得吞错返回 `null` ——
  /// 否则 push 会把 manifest 从零重建、丢失远端独有条目。
  Future<Uint8List?> readObject(String key);

  /// 写入远端对象。失败抛异常。
  Future<void> writeObject(String key, Uint8List bytes);

  /// 是否支持文件直读直写（对象体不进 Dart 内存）。归档类后端为 false。
  bool get supportsFileObjects;

  /// [readObject] 的落盘版。返回 false = 远端不存在（不建文件）。
  Future<bool> readObjectToFile(String key, String filePath);

  /// [writeObject] 的文件版。
  Future<void> writeObjectFile(String key, String filePath);

  /// 条件创建：仅当对象不存在时写入。`false` = 远端已存在（412），其它错误抛
  /// [SyncException]。原子性取决于服务器对 `If-None-Match: *` 的支持 —— 不支持的
  /// 会覆盖写并返回 `true`，调用方（租约锁）须用「写后回读校验」兜底。
  Future<bool> tryCreateExclusive(String key, Uint8List bytes);

  /// 删除远端对象。「不存在」视为成功静默返回；其它错误必须抛 [SyncException]，
  /// 引擎据此决定 tombstone 是否真的已被远端接收。
  Future<void> deleteObject(String key);

  /// 查询远端对象是否存在（HEAD，不下载内容）。返回不透明的 Last-Modified 记号
  /// （格式因后端而异，调用方只做「存在性 + 变没变」判断，不解析）；null = 不存在。
  /// 网络 / 认证 / 服务器错误必须抛 [SyncException]——吞错当成 null 会让 push 把
  /// 已上传媒体判成缺失整体重传、把「远端不可达」判成「远端没有」（与 [readObject]
  /// 同一条纪律）。
  Future<String?> statObject(String key);
}

abstract class IRemoteSyncBackend implements SyncBackend, RemoteObjectStore {
  factory IRemoteSyncBackend.get() => RemoteSyncRegistry.get().backend;

  /// 与 KV `syncProvider` 对齐的 provider 类型。
  SyncProviderType get type;

  /// 探测连通性 / 凭据。失败返回错误信息，成功返回 `null`。
  Future<String?> testConnection();

  /// 双向同步：同一把锁内先 pull 再 push，原子完成、不与其它操作交叠。
  Future<SyncReport> syncAll();
}

class SyncReport {
  final int diaryCount;
  final int categoryCount;
  final int mediaInfoCount;
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
    this.mediaInfoCount = 0,
    required this.elapsed,
    this.warning,
    this.failed = 0,
    this.cancelled = false,
  });

  /// 仅供日志 / payload，**禁止进 UI**——硬编码中文；给用户的摘要逐字段走 l10n
  /// （范例：lan_receive_page 的 _summary、export_page 的 restoreSummary）。
  @override
  String toString() =>
      '日记 $diaryCount 条 / 分类 $categoryCount 条 / 媒体信息 $mediaInfoCount 条'
      '（耗时 ${elapsed.inMilliseconds}ms）'
      '${warning == null ? '' : '\n$warning'}';
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => 'SyncException: $message';
}

/// 远端已被**另一把 DEK** 加密，本机密钥解不开。
///
/// 与普通 [SyncException] 分开是因为引擎的 keyfile 补传前奏对失败的默认处理是
/// 「记 warn 后继续同步」，而这一种必须中止：继续下去要么用错误的密钥覆盖远端
/// 唯一的信封，要么在半路以「密码错误」这类无从下手的错误收场。
class SyncKeyConflictException extends SyncException {
  const SyncKeyConflictException(super.message);
}
