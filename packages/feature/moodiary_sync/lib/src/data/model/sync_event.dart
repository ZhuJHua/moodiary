/// 同步引擎发射的单条事件 —— UI 实时事件流和按天滚动的 `.jsonl` 日志共用此模型。
///
/// 事件本身只携带机器可读字段（kind / level / reason / payload）：展示文案由日志页
/// 按 [SyncEventKind] 取 l10n，同一 kind 下需要细分语义时用 [SyncEventReason]，
/// 其余细节（标题、字节数、异常串等）进 [payload]。不要把已翻译的文案写进事件——
/// jsonl 会跨语言环境被读回。
///
/// 序列化字段刻意保持稳定（jsonl 文件可能升级后被旧字段读到），新增字段请用 nullable
/// 并在 [fromJson] 兜底。
enum SyncEventLevel { info, warn, error }

enum SyncEventKind {
  syncStart,
  syncEnd,
  manifestRead,
  manifestWrite,
  diaryUpload,
  diaryDownload,
  diarySkip,
  diaryTombstonePush,
  diaryTombstonePull,
  categoryUpload,
  categoryDownload,
  categorySkip,
  categoryTombstonePush,
  categoryTombstonePull,
  mediaInfoUpload,
  mediaInfoDownload,
  mediaInfoSkip,
  mediaInfoTombstonePush,
  mediaInfoTombstonePull,
  mediaUpload,
  mediaDownload,
  mediaSkip,
  mediaDelete,
  lockAcquire,
  lockRelease,
  keyfileUpload,
  keyConflict,
  reCipher,
  error,
}

/// 同一 [SyncEventKind] 下的细分语义（如各种「跳过」各自的原因），随事件持久化，
/// 日志页按枚举名取对应 l10n 文案。
enum SyncEventReason {
  /// 本地版本不旧于远端（push / pull 的常规跳过）。
  upToDate,

  /// 远端条目比本地删除更新（tombstone 推送被 LWW 拦下）。
  remoteNewer,

  /// 本地编辑比远端删除更新（pull tombstone 被本地 LWW 拦下）。
  localNewer,

  /// 日记正在编辑器中打开，暂不应用远端删除。
  openDiary,

  /// 本地媒体文件缺失，跳过上传。
  localMissing,

  /// 远端存在性探测失败，按未知处理继续上传。
  probeFailed,

  /// 远端已存在，跳过上传。
  remoteExists,

  /// 本地已存在，跳过下载。
  localExists,

  /// 远端没有该媒体，跳过下载。
  remoteMissing,

  /// 接管本机崩溃残留的同步锁。
  takeover,

  /// 清除他人过期的同步锁。
  expiredLock,

  /// 服务器的条件写已验证原子，后续免回读。
  casVerified,

  /// 服务器不执行条件写，保留回读校验。
  casUnsupported,

  /// 同步锁续租失败。
  renewFailed,

  /// 同步锁释放失败。
  releaseFailed,

  /// 远端对象解码出来不是预期的 JSON 对象。
  decodeFailed,

  /// 墓碑行的前缀无法识别（损坏行 / 未来版本写入），跳过推送。
  unknownTombstone,

  /// 同步被手动停止。
  stopped,

  /// 同步因异常中止。
  aborted,
}

class SyncEvent {
  final DateTime at;
  final SyncEventLevel level;
  final SyncEventKind kind;
  final SyncEventReason? reason;
  final Map<String, Object?>? payload;

  SyncEvent({
    required this.at,
    required this.level,
    required this.kind,
    this.reason,
    this.payload,
  });

  factory SyncEvent.now({
    required SyncEventLevel level,
    required SyncEventKind kind,
    SyncEventReason? reason,
    Map<String, Object?>? payload,
  }) => SyncEvent(
    at: .now(),
    level: level,
    kind: kind,
    reason: reason,
    payload: payload,
  );

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'level': level.name,
    'kind': kind.name,
    if (reason != null) 'reason': reason!.name,
    if (payload != null && payload!.isNotEmpty) 'payload': payload,
  };

  /// 容错解析：未知 level / kind 落到 [SyncEventLevel.info] / [SyncEventKind.error]，
  /// 未知 reason 落到 null，时间无法解析则用 [DateTime.fromMillisecondsSinceEpoch]
  /// 0 时刻占位。
  factory SyncEvent.fromJson(Map<String, Object?> json) {
    SyncEventLevel parseLevel(Object? v) {
      if (v is! String) return .info;
      return SyncEventLevel.values.firstWhere(
        (e) => e.name == v,
        orElse: () => .info,
      );
    }

    SyncEventKind parseKind(Object? v) {
      if (v is! String) return .error;
      return SyncEventKind.values.firstWhere(
        (e) => e.name == v,
        orElse: () => .error,
      );
    }

    SyncEventReason? parseReason(Object? v) {
      if (v is! String) return null;
      for (final r in SyncEventReason.values) {
        if (r.name == v) return r;
      }
      return null;
    }

    final at =
        DateTime.tryParse(json['at'] as String? ?? '') ??
        .fromMillisecondsSinceEpoch(0);
    final raw = json['payload'];
    final payload = raw is Map<String, Object?>
        ? Map<String, Object?>.from(raw)
        : raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : null;
    return SyncEvent(
      at: at,
      level: parseLevel(json['level']),
      kind: parseKind(json['kind']),
      reason: parseReason(json['reason']),
      payload: payload,
    );
  }
}
