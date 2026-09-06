import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_sync/src/data/sync.dart';

class ManifestEntry {
  final int timeMs;
  final bool deleted;
  final List<String> media;

  const ManifestEntry({
    required this.timeMs,
    this.deleted = false,
    this.media = const [],
  });

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

class SyncManifest {
  static const int currentVersion = 2;

  static const int legacyVersion = 1;

  final int version;

  final int updatedAtMs;
  final Map<String, ManifestEntry> entries;

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
    final version = json['version'] is int ? json['version'] as int : 0;
    if (version != currentVersion && version != legacyVersion) {
      throw SyncException(
        l10n.sync.errManifestVersion(remote: version, local: currentVersion),
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
      throw SyncException(l10n.sync.errManifestEntriesCorrupt);
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

  SyncManifest copyForUpdate() => SyncManifest(
    version: currentVersion,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    entries: Map<String, ManifestEntry>.from(entries),
    writeToken: writeToken,
  );

  SyncManifest withWriteToken(String token) => SyncManifest(
    version: version,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    entries: entries,
    writeToken: token,
  );

  Set<String> referencedMedia() => {
    for (final e in entries.values)
      if (!e.deleted) ...e.media,
  };
}

class SyncKeys {
  static const String diaryPrefix = 'd:';
  static const String categoryPrefix = 'c:';
  static const String mediaInfoPrefix = 'm:';
  static const String placePrefix = 'p:';

  static String diary(String id) => '$diaryPrefix$id';
  static String category(String id) => '$categoryPrefix$id';
  static String mediaInfo(String fileName) => '$mediaInfoPrefix$fileName';
  static String place(String id) => '$placePrefix$id';

  static const String manifestPath = 'manifest.json';

  static const String lockPath = 'sync.lock';

  static const String keysPath = 'keys.json';

  static String diaryObjectPath(String id) => 'diary/$id.json';

  static String categoryObjectPath(String id) => 'category/$id.json';

  static String placeObjectPath(String id) => 'place/$id.json';

  static String mediaInfoObjectPath(String fileName) =>
      'mediainfo/${mediaTypeOfFileName(fileName)}/$fileName.json';

  static String mediaObjectPath(String type, String filename) =>
      'media/$type/$filename';

  static String mediaRef(String type, String filename) => '$type/$filename';

  static String mediaObjectPathFromRef(String ref) => 'media/$ref';
}
