// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。
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
