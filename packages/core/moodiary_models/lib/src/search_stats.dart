import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'search_stats.freezed.dart';
part 'search_stats.g.dart';

/// 搜索全局统计单例（@Id 恒为 0）。[docCount] = 已索引篇数（BM25 的 N）；
/// [contentDocCount] = 其中正文非空的篇数，avgdl 只对它们平均——纯媒体/仅标题的
/// 日记不摊薄正文均长，否则长文会被长度归一过度惩罚。与倒排同事务增量维护，重建时重算。
@freezed
@Collection(ignore: {'copyWith'})
abstract class SearchStats with _$SearchStats {
  const factory SearchStats({
    @Id() required int id,
    required int docCount,
    required int contentDocCount,
    required int totalContentChars,
  }) = _SearchStats;

  const SearchStats._();
}
