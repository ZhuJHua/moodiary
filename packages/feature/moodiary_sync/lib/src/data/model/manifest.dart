import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 单个 manifest 条目。JSON：`{"t": <ms>, "d": true?, "m": ["image/a.png", ...]?}`
/// - `t`：普通条目 lastModified、tombstone 删除时间的**毫秒戳**，仅用于 LWW 比较。
///   全程纯 int（本地侧取 `lastModified.millisecondsSinceEpoch`），不经 DateTime，
///   故无「本地微秒 vs 远端毫秒」精度错位；毫秒足够（跨设备时钟偏差远大于毫秒）；
/// - `d`：tombstone 标记，省略即 false；
/// - `m`：该条目引用的远端媒体相对路径（`<type>/<filename>`，**含视频缩略图**）。
///   引擎据此构建「远端已有媒体」集合；tombstone / 分类条目省略。
class ManifestEntry {
  final int timeMs;
  final bool deleted;
  final List<String> media;

  const ManifestEntry({
    required this.timeMs,
    this.deleted = false,
    this.media = const [],
  });

  /// 时间戳缺失/损坏返回 null，由 [SyncManifest.fromJson] 丢弃该条目（单条损坏
  /// 不应让整个同步失败）。
  static ManifestEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final t = json['t'];
    if (t is! int) return null;
    return ManifestEntry(
      timeMs: t,
      deleted: json['d'] == true,
      media: [
        if (json['m'] is List) ...(json['m'] as List).whereType<String>(),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    't': timeMs,
    if (deleted) 'd': true,
    if (media.isNotEmpty) 'm': media,
  };
}

/// 远端 manifest 模型 —— 描述「远端有哪些 item、各自版本与媒体引用」。时间一律
/// 为 millisecondsSinceEpoch 整数。key 用 `kind:id`（`d:` 日记、`c:` 分类）。
/// JSON：
/// ```json
/// {
///   "version": 4,
///   "updatedAt": 1780000000000,
///   "entries": {
///     "d:<diaryId>": {"t": 1780000000000, "m": ["image/a.png"]},
///     "d:<deletedId>": {"t": 1780000000000, "d": true},
///     "c:<categoryId>": {"t": 1780000000000}
///   }
/// }
/// ```
/// 版本严格匹配：[fromJson] 对 `version != 4` 抛 [SyncException]，含**更高版本**
/// —— 静默丢条目会诱发「push 用本地重建 manifest」的数据丢失，宁可拒绝同步。
/// 密钥正确性由解密时的 AES-GCM auth tag 一票否决，manifest 自身不持密钥材料。
class SyncManifest {
  static const int currentVersion = 4;

  final int version;

  /// 最近一次写回的毫秒戳，仅供人工排查，不参与逻辑。
  final int updatedAtMs;
  final Map<String, ManifestEntry> entries;

  /// 每次写回时由写入方生成的唯一标记（`<deviceId>:<micros>:<seq>`）。push 写完后
  /// **回读校验**此 token 仍是自己写的，借此发现「租约被绕过、另一台设备并发覆盖了
  /// manifest」—— 不依赖服务器是否支持 HTTP 条件写，任意后端可用。空串 = 尚未写过 /
  /// 旧格式。
  final String writeToken;

  SyncManifest({
    required this.version,
    required this.updatedAtMs,
    required this.entries,
    this.writeToken = '',
  });

  factory SyncManifest.empty() => SyncManifest(
    version: currentVersion,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    entries: <String, ManifestEntry>{},
  );

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    // 非 int 的 version（被改成字符串/小数）也走版本守卫抛 SyncException，
    // 而不是 `as int?` 抛裸 TypeError。
    final version = json['version'] is int ? json['version'] as int : 0;
    if (version != currentVersion) {
      throw SyncException(
        '远端备份格式版本不兼容（远端 v$version，本机 v$currentVersion）。'
        '请用对应版本的客户端同步，或清空远端备份目录后重新上传。',
      );
    }
    final entriesRaw = json['entries'];
    final entries = <String, ManifestEntry>{};
    if (entriesRaw is Map) {
      entriesRaw.forEach((k, v) {
        if (k is! String) return;
        final entry = ManifestEntry.fromJson(v);
        if (entry != null) entries[k] = entry;
      });
    } else if (entriesRaw != null) {
      // entries 字段存在但不是对象（被外部覆盖成 array/字符串/数字）= manifest 损坏。
      // 绝不能静默当作空清单 —— 否则 push 用本地重建 manifest、丢掉仅远端有的条目（契约一）。
      throw const SyncException(
        '远端 manifest 的 entries 字段已损坏（非对象），已中止同步以防丢失远端条目',
      );
    }
    final updatedAtRaw = json['updatedAt'];
    return SyncManifest(
      version: version,
      updatedAtMs: updatedAtRaw is int ? updatedAtRaw : 0,
      entries: entries,
      writeToken: json['w'] is String ? json['w'] as String : '',
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAt': updatedAtMs,
    if (writeToken.isNotEmpty) 'w': writeToken,
    'entries': entries.map((k, v) => MapEntry(k, v.toJson())),
  };

  /// 浅拷贝，供 push 过程中对 [entries] 增量更新（[ManifestEntry] 不可变，共享无碍）。
  SyncManifest copyForUpdate() => SyncManifest(
    version: version,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    entries: Map<String, ManifestEntry>.from(entries),
    writeToken: writeToken,
  );

  /// 提交前给本次写入打上唯一 [writeToken]，供写后回读校验并发覆盖。
  SyncManifest withWriteToken(String token) => SyncManifest(
    version: version,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    entries: entries,
    writeToken: token,
  );

  /// 所有非 tombstone 条目引用的媒体并集 = 「远端应当已有」的媒体。「媒体先传、
  /// manifest 后写」保证集合内对象真实存在；集合外的（中断残留）由调用方 stat 兜底。
  Set<String> referencedMedia() => {
    for (final e in entries.values)
      if (!e.deleted) ...e.media,
  };
}

/// manifest key 命名约定。
class SyncKeys {
  static const String diaryPrefix = 'd:';
  static const String categoryPrefix = 'c:';
  static const String mediaInfoPrefix = 'm:';

  static String diary(String id) => '$diaryPrefix$id';
  static String category(String id) => '$categoryPrefix$id';
  static String mediaInfo(String fileName) => '$mediaInfoPrefix$fileName';

  static const String manifestPath = 'manifest.json';

  /// 远端同步锁文件路径（明文租约 JSON，见 `RemoteLease`）。
  static const String lockPath = 'sync.lock';

  /// 密钥文件路径（明文 JSON：盐 + KDF 参数 + 密码包裹的 DEK，见 `SyncKeyfile`）。
  static const String keysPath = 'keys.json';

  static String diaryObjectPath(String id) => 'diary/$id.json';

  static String categoryObjectPath(String id) => 'category/$id.json';

  /// 媒体元数据对象路径，按类型分子目录（`mediainfo/audio/…`，类型取自文件名
  /// 前缀），与媒体本体目录 `media/<type>/` 平行、互不混淆。
  static String mediaInfoObjectPath(String fileName) =>
      'mediainfo/${mediaTypeOfFileName(fileName)}/$fileName.json';

  /// [type] 为 `image` / `audio` / `video`。
  static String mediaObjectPath(String type, String filename) =>
      'media/$type/$filename';

  /// manifest 条目里的媒体相对引用（`<type>/<filename>`）。
  static String mediaRef(String type, String filename) => '$type/$filename';

  static String mediaObjectPathFromRef(String ref) => 'media/$ref';
}
