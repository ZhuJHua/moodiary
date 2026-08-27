import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_tombstone.freezed.dart';
part 'sync_tombstone.g.dart';

/// 同步墓碑：日记 / 分类 / 媒体元数据被永久删除后，行本体立即从各自表中硬删，
/// 删除事实以本表一行承载并向同步边界（云后端 / 局域网 / 本地归档）传播。与
/// 日记表分离——墓碑不给业务查询加税，也不残留正文明文。
///
/// - [key] 即 manifest 条目键（`d:<diaryId>` / `c:<categoryId>` / `m:<fileName>`），
///   与远端格式一一对应；前缀必须恰好 2 字符（[entityId] 依赖）；
/// - [timeMs] 为删除时刻的毫秒戳，即 LWW 时钟（对应 manifest 的 `t`，全程纯 int）；
/// - [pushedBackends] 记录墓碑已推送到哪些云后端（persistentBackendId）。覆盖全部
///   已配置云后端后行才被清除；日记复活（pull 下载同 id）时行连带删除，历史推送
///   记录不会误判下一次删除。
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

  /// null = 未知前缀（异常/未来版本的墓碑行）：调用方跳过而不是崩掉整次同步。
  TombstoneKind? get kind {
    if (key.length < 2) return null;
    return switch (key.substring(0, 2)) {
      diaryPrefix => .diary,
      categoryPrefix => .category,
      mediaInfoPrefix => .mediaInfo,
      _ => null,
    };
  }

  /// 去掉 kind 前缀后的业务 id。
  String get entityId => key.substring(2);

  factory SyncTombstone.fromJson(Map<String, dynamic> json) =>
      _$SyncTombstoneFromJson(json);
}

enum TombstoneKind { diary, category, mediaInfo }
