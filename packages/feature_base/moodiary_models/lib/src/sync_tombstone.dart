import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_tombstone.freezed.dart';
part 'sync_tombstone.g.dart';

@freezed
abstract class SyncTombstone with _$SyncTombstone {
  const factory SyncTombstone({
    required String key,
    required int timeMs,
    required List<String> pushedBackends,
  }) = _SyncTombstone;

  const SyncTombstone._();

  static const String diaryPrefix = 'd:';
  static const String categoryPrefix = 'c:';
  static const String mediaInfoPrefix = 'm:';
  static const String placePrefix = 'p:';

  static String diaryKey(String diaryId) => '$diaryPrefix$diaryId';
  static String categoryKey(String categoryId) => '$categoryPrefix$categoryId';
  static String mediaInfoKey(String fileName) => '$mediaInfoPrefix$fileName';
  static String placeKey(String placeId) => '$placePrefix$placeId';

  factory SyncTombstone.forDiary(String diaryId, {required DateTime at}) =>
      SyncTombstone(
        key: diaryKey(diaryId),
        timeMs: at.millisecondsSinceEpoch,
        pushedBackends: const [],
      );

  factory SyncTombstone.forCategory(
    String categoryId, {
    required DateTime at,
  }) => SyncTombstone(
    key: categoryKey(categoryId),
    timeMs: at.millisecondsSinceEpoch,
    pushedBackends: const [],
  );

  factory SyncTombstone.forMediaInfo(String fileName, {required DateTime at}) =>
      SyncTombstone(
        key: mediaInfoKey(fileName),
        timeMs: at.millisecondsSinceEpoch,
        pushedBackends: const [],
      );

  factory SyncTombstone.forPlace(String placeId, {required DateTime at}) =>
      SyncTombstone(
        key: placeKey(placeId),
        timeMs: at.millisecondsSinceEpoch,
        pushedBackends: const [],
      );

  TombstoneKind? get kind {
    if (key.length < 2) return null;
    return switch (key.substring(0, 2)) {
      diaryPrefix => .diary,
      categoryPrefix => .category,
      mediaInfoPrefix => .mediaInfo,
      placePrefix => .place,
      _ => null,
    };
  }

  String get entityId => key.substring(2);

  factory SyncTombstone.fromJson(Map<String, dynamic> json) =>
      _$SyncTombstoneFromJson(json);
}

enum TombstoneKind { diary, category, mediaInfo, place }
