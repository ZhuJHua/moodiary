/// 同步引擎发射的单条事件 —— UI 实时事件流和按天滚动的 `.jsonl` 日志共用此模型。
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
  mediaUpload,
  mediaDownload,
  mediaSkip,
  mediaDelete,
  lockAcquire,
  lockRelease,
  error,
}

class SyncEvent {
  final DateTime at;
  final SyncEventLevel level;
  final SyncEventKind kind;
  final String message;
  final Map<String, Object?>? payload;

  SyncEvent({
    required this.at,
    required this.level,
    required this.kind,
    required this.message,
    this.payload,
  });

  factory SyncEvent.now({
    required SyncEventLevel level,
    required SyncEventKind kind,
    required String message,
    Map<String, Object?>? payload,
  }) => SyncEvent(
    at: DateTime.now(),
    level: level,
    kind: kind,
    message: message,
    payload: payload,
  );

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'level': level.name,
    'kind': kind.name,
    'message': message,
    if (payload != null && payload!.isNotEmpty) 'payload': payload,
  };

  /// 容错解析：未知 level / kind 落到 [SyncEventLevel.info] / [SyncEventKind.error]，
  /// 时间无法解析则用 [DateTime.fromMillisecondsSinceEpoch] 0 时刻占位。
  factory SyncEvent.fromJson(Map<String, Object?> json) {
    SyncEventLevel parseLevel(Object? v) {
      if (v is! String) return SyncEventLevel.info;
      return SyncEventLevel.values.firstWhere(
        (e) => e.name == v,
        orElse: () => SyncEventLevel.info,
      );
    }

    SyncEventKind parseKind(Object? v) {
      if (v is! String) return SyncEventKind.error;
      return SyncEventKind.values.firstWhere(
        (e) => e.name == v,
        orElse: () => SyncEventKind.error,
      );
    }

    final at =
        DateTime.tryParse(json['at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
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
      message: (json['message'] as String?) ?? '',
      payload: payload,
    );
  }
}
