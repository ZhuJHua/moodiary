enum SyncEventLevel { info, warn, error }

enum SyncTrigger {
  manual,
  change,
  close,
  poll,
  resume,
  network,
}

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
  placeUpload,
  placeDownload,
  placeSkip,
  placeTombstonePush,
  placeTombstonePull,
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

enum SyncEventReason {
  upToDate,

  remoteNewer,

  localNewer,

  openDiary,

  localMissing,

  probeFailed,

  recovered,

  remoteExists,

  localExists,

  remoteMissing,

  takeover,

  expiredLock,

  casVerified,

  casUnsupported,

  renewFailed,

  releaseFailed,

  decodeFailed,

  unknownTombstone,

  stopped,

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
