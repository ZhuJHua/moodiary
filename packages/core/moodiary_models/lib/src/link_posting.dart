import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'link_posting.freezed.dart';
part 'link_posting.g.dart';

/// 双链反向 posting-list：`key = fastHash(toId)`（目标日记业务 id）→ 正文链接到它的
/// 源日记 isarId 列表。与 [SearchPosting] 同范式（主键 get + 快照 diff 维护）。
@freezed
@Collection(ignore: {'copyWith'})
abstract class LinkPosting with _$LinkPosting {
  const factory LinkPosting({
    @Id() required int key,
    required List<int> fromIsarIds,
  }) = _LinkPosting;

  const LinkPosting._();
}
