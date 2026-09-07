import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'sync_tombstone.freezed.dart';
part 'sync_tombstone.g.dart';

@freezed
// isar_plus 会把公开 getter 一并持久化，kind 是派生属性须显式 ignore。
@Collection(ignore: {'copyWith', 'kind'})
abstract class SyncTombstone with _$SyncTombstone {
  const factory SyncTombstone({
    required String key,
    required int timeMs,
    required List<String> pushedBackends,
  }) = _SyncTombstone;

  const SyncTombstone._();

  @Id()
  int get isarId => fastHash(key);

  static const String diaryPrefix = 'd:';
  static const String categoryPrefix = 'c:';
  static const String mediaInfoPrefix = 'm:';

  static String diaryKey(String diaryId) => '$diaryPrefix$diaryId';
  static String categoryKey(String categoryId) => '$categoryPrefix$categoryId';
  static String mediaInfoKey(String fileName) => '$mediaInfoPrefix$fileName';

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

  bool get isDiary => key.startsWith(diaryPrefix);

  TombstoneKind? get kind {
    if (key.length < 2) return null;
    return switch (key.substring(0, 2)) {
      diaryPrefix => .diary,
      categoryPrefix => .category,
      mediaInfoPrefix => .mediaInfo,
      _ => null,
    };
  }

  String get entityId => key.substring(2);
}

enum TombstoneKind { diary, category, mediaInfo }
