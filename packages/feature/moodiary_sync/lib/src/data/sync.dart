import 'dart:typed_data';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';

/// 同步 / 备份后端的抽象，两层：
///
/// - [RemoteObjectStore]：对象存储原语。**引擎只依赖它**——归档导入这类「只当
///   对象源用」的实现（LocalArchiveBackend）实现到这一层为止。
/// - [IRemoteSyncBackend]：云端后端 = 对象原语 + 配置（provider 类型 / 就绪 / 探测）。
///   push / pull / sync 不长在后端上，调用方走 `IncrementalSyncEngine.forCloud`。
///   各实现以 `@Named(SyncProviderIds.x)` 注册；当前那个由 `activateSyncProvider`
///   开 scope 以无名 [IRemoteSyncBackend] 暴露（sync_provider_scope.dart）。
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

abstract class IRemoteSyncBackend implements RemoteObjectStore {
  /// 与 KV `syncProvider` 对齐的 provider 类型。
  SyncProviderType get type;

  /// 配置是否齐全（例如 WebDAV 是否填了 url / user）。未就绪时引擎入口抛
  /// [notReadyError]；`configuredCloudBackendIds()` 也据此统计。异步：配置在
  /// SecureKV，不在启动时预读，后端首次用到才读（可自缓存，写时作废）。
  Future<bool> isReady();

  /// [isReady] 为假时的配置错误（各后端文案不同）。
  SyncException get notReadyError;

  /// 已保存的连接配置（表单回填用；条目顺序由各后端定义，与 [saveOptions] 对称）。
  Future<List<String>> savedOptions();

  /// 保存连接配置。加密已开启时同时登记 keyfile 待上传：新（重）配置的后端必须
  /// 拿到 keyfile，否则会收到加密对象而无 keys.json，换设备后永远解不开。
  Future<void> saveOptions(List<String> options);

  Future<void> clearOptions();

  /// 探测连通性 / 凭据。失败抛 [SyncException]（带 [SyncErrorKind]），成功静默返回。
  Future<void> testConnection();
}

/// 一个方向上的变更条数。日记 / 分类 / 媒体信息按条目计（含推送或应用的墓碑），
/// [mediaFiles] 是真正传输过的媒体文件数（跳过的不算）。
class SyncCounts {
  final int diaries;
  final int categories;
  final int mediaInfos;
  final int mediaFiles;

  const SyncCounts({
    this.diaries = 0,
    this.categories = 0,
    this.mediaInfos = 0,
    this.mediaFiles = 0,
  });

  static const SyncCounts zero = SyncCounts();

  bool get isEmpty =>
      diaries == 0 && categories == 0 && mediaInfos == 0 && mediaFiles == 0;

  /// 条目级是否有变更（不看媒体文件）：pull 的 skip 分支会补拉缺失媒体，
  /// 那不改 manifest，push 侧据此判断能否复用 pull 读到的快照。
  bool get hasEntryChanges => diaries > 0 || categories > 0 || mediaInfos > 0;

  SyncCounts operator +(SyncCounts other) => SyncCounts(
    diaries: diaries + other.diaries,
    categories: categories + other.categories,
    mediaInfos: mediaInfos + other.mediaInfos,
    mediaFiles: mediaFiles + other.mediaFiles,
  );
}

class SyncReport {
  /// 本地 → 远端（上传 + 推送的墓碑）。
  final SyncCounts pushed;

  /// 远端 → 本地（下载 + 应用的墓碑；归档导入也走这一侧）。
  final SyncCounts pulled;

  final Duration elapsed;
  final String? warning;

  /// 失败（已跳过）的条目数。>0 表示同步不完整，引擎不更新「上次同步时间」、下次重试。
  final int failed;

  /// 被用户手动停止（协作式取消，见 `SyncCancellation`）。已完成条目有效，
  /// 未处理的下次继续；同样不更新「上次同步时间」。
  final bool cancelled;

  /// 因「本机内容不旧于备份」而跳过的条目数。恢复流程要能区分「备份已是最新」
  /// 与「有 N 条因本机更新被跳过」—— 两者此前显示的都是「恢复 0 条」。
  final int skipped;

  /// push 时因「正在编辑器中打开」被排除的日记数。>0 说明本地仍有没推上去的
  /// 变更——调用方不得据此清「待推」标记，否则关闭日记后无人再推。
  final int skippedOpen;

  const SyncReport({
    this.pushed = .zero,
    this.pulled = .zero,
    required this.elapsed,
    this.warning,
    this.failed = 0,
    this.cancelled = false,
    this.skipped = 0,
    this.skippedOpen = 0,
  });

  /// 两个方向合计。局域网接收 / 备份导入 / 导出页仍按合计读，它们只有一个方向。
  int get diaryCount => pushed.diaries + pulled.diaries;
  int get categoryCount => pushed.categories + pulled.categories;
  int get mediaInfoCount => pushed.mediaInfos + pulled.mediaInfos;

  /// 两侧都没动过：远端与本地已一致（失败与停止另看 [failed] / [cancelled]）。
  bool get changedNothing => pushed.isEmpty && pulled.isEmpty;

  /// 面向用户的摘要，逐字段走 l10n。只列非零项，方向分开说；零变更说「没有需要
  /// 同步的内容」而不是「0 条」——这个数字是本轮变更数，不是库里的总数。
  /// UI 一律用这个，别用 [toString]。
  String userSummary() {
    final media = pushed.mediaFiles + pulled.mediaFiles;
    final parts = <String>[
      if (pushed.diaries > 0)
        l10n.sync.summaryUploadedDiaries(count: pushed.diaries),
      if (pushed.categories > 0)
        l10n.sync.summaryUploadedCategories(count: pushed.categories),
      if (pulled.diaries > 0)
        l10n.sync.summaryDownloadedDiaries(count: pulled.diaries),
      if (pulled.categories > 0)
        l10n.sync.summaryDownloadedCategories(count: pulled.categories),
      if (media > 0) l10n.sync.summaryMedia(count: media),
    ];
    final clean = failed == 0 && !cancelled;
    return [
      if (parts.isEmpty && clean) l10n.sync.summaryUpToDate,
      ...parts,
      if (cancelled) l10n.sync.warnStopped,
      if (failed > 0) l10n.sync.warnFailedSkipped(count: failed),
    ].join(' · ');
  }

  /// 仅供日志 / payload，**禁止进 UI**——硬编码中文；给用户的摘要逐字段走 l10n
  /// （范例：lan_receive_page 的 _summary、export_page 的 restoreSummary）。
  @override
  String toString() =>
      '上行 日记 ${pushed.diaries} / 分类 ${pushed.categories} / '
      '媒体信息 ${pushed.mediaInfos} / 媒体 ${pushed.mediaFiles}；'
      '下行 日记 ${pulled.diaries} / 分类 ${pulled.categories} / '
      '媒体信息 ${pulled.mediaInfos} / 媒体 ${pulled.mediaFiles}'
      '（耗时 ${elapsed.inMilliseconds}ms）'
      '${warning == null ? '' : '\n$warning'}';
}

/// 同步错误的机器可读分类。UI 据此给「下一步」（重试 / 检查配置 / 解锁密钥），
/// 连接健康（`SyncHealth`）据此判定远端是否可达。
enum SyncErrorKind {
  /// 连不上：DNS / 拒绝连接 / 超时。
  network,

  /// 401 / 403：凭据失效或权限不足。
  auth,

  /// 404 从对象层冒了上来（正常情况下后端把「不存在」折成 null / false）。
  notFound,

  /// 5xx。
  server,

  /// 其它非 2xx。
  http,

  /// 远端锁被另一台设备持有（远端活着）。
  locked,

  /// manifest 写后回读不是自己写的（远端活着）。
  manifestRace,

  /// 远端 manifest 解不成对象（远端活着，数据坏了）。
  manifestCorrupt,

  /// 远端由另一把密钥加密。
  keyConflict,

  /// 后端配置不齐。
  notConfigured,

  unknown;

  static final RegExp _tag = RegExp(
    r'\[(network|auth|not_found|server|http|unknown)\]',
  );

  /// 从 Rust 侧成文的错误明细里读 `[kind]` 标签（见 moodiary_rust `sync/mod.rs`）。
  /// 标签可能不在开头——Dart 包装层会在前面加自己的一句，FRB 又会套一层
  /// `AnyhowException(...)`，所以扫整串取第一个。没有标签 → [unknown]。
  static SyncErrorKind fromDetail(String detail) {
    final m = _tag.firstMatch(detail);
    return switch (m?.group(1)) {
      'network' => .network,
      'auth' => .auth,
      'not_found' => .notFound,
      'server' => .server,
      'http' => .http,
      _ => .unknown,
    };
  }

  /// 给人看之前把标签摘掉。
  static final RegExp _tagWithSpace = RegExp(
    r'\[(network|auth|not_found|server|http|unknown)\]\s*',
  );

  static String stripTag(String detail) =>
      detail.replaceFirst(_tagWithSpace, '').trim();

  /// 这类错误说明远端本身不可达 / 不接受本机（连接健康要变红）；其余是远端活着
  /// 但这一次没成（锁、竞争、数据坏），健康态不动。
  bool get affectsHealth => switch (this) {
    .network ||
    .auth ||
    .server ||
    .http ||
    .keyConflict ||
    .notConfigured => true,
    _ => false,
  };
}

class SyncException implements Exception {
  final String message;
  final SyncErrorKind kind;
  const SyncException(this.message, {this.kind = .unknown});

  /// 包装底层（Rust）错误：从明细里读分类、摘掉标签与 FRB 的
  /// `AnyhowException(...)` 外壳，再交给 [message] 成文。
  factory SyncException.wrap(
    Object error,
    String Function(String detail) message,
  ) {
    final detail = error is SyncException ? error.message : error.toString();
    return SyncException(
      message(SyncErrorKind.stripTag(_unwrapAnyhow(detail))),
      kind: error is SyncException
          ? error.kind
          : SyncErrorKind.fromDetail(detail),
    );
  }

  static final RegExp _anyhow = RegExp(
    r'^AnyhowException\((.*)\)$',
    dotAll: true,
  );

  static String _unwrapAnyhow(String detail) =>
      _anyhow.firstMatch(detail.trim())?.group(1) ?? detail;

  @override
  String toString() => 'SyncException: $message';
}

/// 远端已被**另一把 DEK** 加密，本机密钥解不开。
///
/// 与普通 [SyncException] 分开是因为引擎的 keyfile 补传前奏对失败的默认处理是
/// 「记 warn 后继续同步」，而这一种必须中止：继续下去要么用错误的密钥覆盖远端
/// 唯一的信封，要么在半路以「密码错误」这类无从下手的错误收场。
class SyncKeyConflictException extends SyncException {
  const SyncKeyConflictException(super.message) : super(kind: .keyConflict);
}
