import 'dart:typed_data';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';

abstract class RemoteObjectStore {
  String get displayName;

  String? get persistentBackendId;

  Future<Uint8List?> readObject(String key);

  Future<void> writeObject(String key, Uint8List bytes);

  bool get supportsFileObjects;

  Future<bool> readObjectToFile(String key, String filePath);

  Future<void> writeObjectFile(String key, String filePath);

  Future<bool> tryCreateExclusive(String key, Uint8List bytes);

  Future<void> deleteObject(String key);

  Future<String?> statObject(String key);
}

abstract class IRemoteSyncBackend implements RemoteObjectStore {
  SyncProviderType get type;

  Future<bool> isReady();

  SyncException get notReadyError;

  Future<List<String>> savedOptions();

  Future<void> saveOptions(List<String> options);

  Future<void> clearOptions();

  Future<void> testConnection();
}

class SyncCounts {
  final int diaries;
  final int categories;
  final int places;
  final int mediaInfos;
  final int mediaFiles;

  const SyncCounts({
    this.diaries = 0,
    this.categories = 0,
    this.places = 0,
    this.mediaInfos = 0,
    this.mediaFiles = 0,
  });

  static const SyncCounts zero = SyncCounts();

  bool get isEmpty =>
      diaries == 0 &&
      categories == 0 &&
      places == 0 &&
      mediaInfos == 0 &&
      mediaFiles == 0;

  bool get hasEntryChanges =>
      diaries > 0 || categories > 0 || places > 0 || mediaInfos > 0;

  SyncCounts operator +(SyncCounts other) => SyncCounts(
    diaries: diaries + other.diaries,
    categories: categories + other.categories,
    places: places + other.places,
    mediaInfos: mediaInfos + other.mediaInfos,
    mediaFiles: mediaFiles + other.mediaFiles,
  );
}

class SyncReport {
  final SyncCounts pushed;

  final SyncCounts pulled;

  final Duration elapsed;
  final String? warning;

  final int failed;

  final bool cancelled;

  final int skipped;

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

  int get diaryCount => pushed.diaries + pulled.diaries;
  int get categoryCount => pushed.categories + pulled.categories;
  int get mediaInfoCount => pushed.mediaInfos + pulled.mediaInfos;

  bool get changedNothing => pushed.isEmpty && pulled.isEmpty;

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

  @override
  String toString() =>
      '上行 日记 ${pushed.diaries} / 分类 ${pushed.categories} / '
      '媒体信息 ${pushed.mediaInfos} / 媒体 ${pushed.mediaFiles}；'
      '下行 日记 ${pulled.diaries} / 分类 ${pulled.categories} / '
      '媒体信息 ${pulled.mediaInfos} / 媒体 ${pulled.mediaFiles}'
      '（耗时 ${elapsed.inMilliseconds}ms）'
      '${warning == null ? '' : '\n$warning'}';
}

enum SyncErrorKind {
  network,

  auth,

  notFound,

  server,

  http,

  locked,

  manifestRace,

  manifestCorrupt,

  keyConflict,

  notConfigured,

  unknown;

  static final RegExp _tag = RegExp(
    r'\[(network|auth|not_found|server|http|unknown)\]',
  );

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

  static final RegExp _tagWithSpace = RegExp(
    r'\[(network|auth|not_found|server|http|unknown)\]\s*',
  );

  static String stripTag(String detail) =>
      detail.replaceFirst(_tagWithSpace, '').trim();

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

class SyncKeyConflictException extends SyncException {
  const SyncKeyConflictException(super.message) : super(kind: .keyConflict);
}
