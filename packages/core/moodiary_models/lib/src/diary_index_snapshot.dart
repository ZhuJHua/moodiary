import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'diary_index_snapshot.freezed.dart';
part 'diary_index_snapshot.g.dart';

/// 正向快照：某日记当前已进入倒排的分词与双链目标。重索引时与新值求 diff，
/// 只改动受影响的 posting 行；也是删除日记时摘除 posting 的唯一依据。
@freezed
@Collection(ignore: {'copyWith'})
abstract class DiaryIndexSnapshot with _$DiaryIndexSnapshot {
  const factory DiaryIndexSnapshot({
    @Id() required int diaryIsarId,
    required List<String> cutTokens,
    required List<String> cutForSearchTokens,
    required List<String> linkToIds,
  }) = _DiaryIndexSnapshot;

  const DiaryIndexSnapshot._();
}
