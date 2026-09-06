// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'diary_index_snapshot.freezed.dart';
part 'diary_index_snapshot.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class DiaryIndexSnapshot with _$DiaryIndexSnapshot {
  const factory DiaryIndexSnapshot({
    @Id() required int diaryIsarId,
    required List<String> cutTokens,
    required List<int> cutFreqs,
    required List<String> cutForSearchTokens,
    required List<int> cutForSearchFreqs,
    required List<String> titleTokens,
    required List<int> titleFreqs,
    required List<String> linkToIds,
    required int contentChars,
  }) = _DiaryIndexSnapshot;

  const DiaryIndexSnapshot._();
}
