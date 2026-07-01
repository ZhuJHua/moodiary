import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'diary_search_index.freezed.dart';
part 'diary_search_index.g.dart';

enum TokenSource { cut, cutForSearch }

/// 倒排索引条目：token → diaryIsarId，按 [source] 区分精确/召回分词。
@freezed
@Collection(ignore: {'copyWith'})
abstract class DiarySearchIndex with _$DiarySearchIndex {
  const factory DiarySearchIndex({
    @Id() required int id,
    @Index(hash: true) required String token,
    required int diaryIsarId,
    required TokenSource source,
  }) = _DiarySearchIndex;

  const DiarySearchIndex._();
}
