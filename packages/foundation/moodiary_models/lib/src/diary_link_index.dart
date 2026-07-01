import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'diary_link_index.freezed.dart';
part 'diary_link_index.g.dart';

/// 双链反向索引条目：`toId`（目标日记业务 id）→ `fromIsarId`（源日记 isarId）。
/// 反链查询走 `where().toIdEqualTo(目标)`；源日记更新/删除时按 `fromIsarId` 清理。
/// 与 [DiarySearchIndex] 同范式（同一套 insert/update/delete/repair 维护）。
@freezed
@Collection(ignore: {'copyWith'})
abstract class DiaryLinkIndex with _$DiaryLinkIndex {
  const factory DiaryLinkIndex({
    @Id() required int id,
    @Index(hash: true) required String toId,
    required int fromIsarId,
  }) = _DiaryLinkIndex;

  const DiaryLinkIndex._();
}
