import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'search_posting.freezed.dart';
part 'search_posting.g.dart';

/// [title] 为标题命名空间（细粒度分词），与正文双源并列;枚举只用于 key 前缀,不落库。
enum TokenSource { cut, cutForSearch, title }

/// 全文倒排 posting-list：`key = fastHash('${source.name}:$token')` → 含该词的日记
/// isarId 列表 + 平行的词频数组（BM25 的 TF；行长即 DF）。isar_plus 引擎读查询不走
/// 二级索引（全表扫描），只有主键 get 是 O(1)，故倒排必须以主键组织；维护走
/// [DiaryIndexSnapshot] 的 diff，天然幂等。
@freezed
@Collection(ignore: {'copyWith'})
abstract class SearchPosting with _$SearchPosting {
  const factory SearchPosting({
    @Id() required int key,
    required List<int> diaryIsarIds,
    required List<int> termFreqs,
  }) = _SearchPosting;

  const SearchPosting._();
}
