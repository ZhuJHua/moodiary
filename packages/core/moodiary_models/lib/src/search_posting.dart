import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'search_posting.freezed.dart';
part 'search_posting.g.dart';

enum TokenSource { cut, cutForSearch }

/// 全文倒排 posting-list：`key = fastHash('${source.name}:$token')` → 含该词的日记
/// isarId 列表。isar_plus 引擎读查询不走二级索引（全表扫描），只有主键 get 是 O(1)，
/// 故倒排必须以主键组织；维护走 [DiaryIndexSnapshot] 的 diff，天然幂等。
@freezed
@Collection(ignore: {'copyWith'})
abstract class SearchPosting with _$SearchPosting {
  const factory SearchPosting({
    @Id() required int key,
    required List<int> diaryIsarIds,
  }) = _SearchPosting;

  const SearchPosting._();
}
