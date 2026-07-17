import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'sync_tombstone.freezed.dart';
part 'sync_tombstone.g.dart';

/// 同步墓碑：日记 / 分类被永久删除后，行本体立即从各自表中硬删，删除事实以本表
/// 一行承载并向同步边界（云后端 / 局域网 / 本地归档）传播。与日记表分离——墓碑
/// 不再给业务查询的全表扫描加税，也不残留正文明文。
///
/// - [key] 即 manifest 条目键（`d:<diaryId>` / `c:<categoryId>`），与远端格式一一对应；
/// - [timeMs] 为删除时刻的毫秒戳，即 LWW 时钟（对应 manifest 的 `t`，全程纯 int）；
/// - [pushedBackends] 记录墓碑已推送到哪些云后端（persistentBackendId）。覆盖全部
///   已配置云后端后行才被清除；日记复活（pull 下载同 id）时行连带删除，历史推送
///   记录不会误判下一次删除。
@freezed
@Collection(ignore: {'copyWith'})
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

  static String diaryKey(String diaryId) => '$diaryPrefix$diaryId';
  static String categoryKey(String categoryId) => '$categoryPrefix$categoryId';

  factory SyncTombstone.forDiary(String diaryId, {required DateTime at}) =>
      SyncTombstone(
        key: diaryKey(diaryId),
        timeMs: at.millisecondsSinceEpoch,
        pushedBackends: const [],
      );

  factory SyncTombstone.forCategory(String categoryId, {required DateTime at}) =>
      SyncTombstone(
        key: categoryKey(categoryId),
        timeMs: at.millisecondsSinceEpoch,
        pushedBackends: const [],
      );

  bool get isDiary => key.startsWith(diaryPrefix);

  /// 去掉 kind 前缀后的业务 id。
  String get entityId => key.substring(2);
}
