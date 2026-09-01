// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'diary_index_snapshot.freezed.dart';
part 'diary_index_snapshot.g.dart';

/// 正向快照：某日记当前已进入倒排的分词（含词频，与词表平行）、标题分词与双链目标。
/// 重索引时与新值求 diff（词频变化也视为变更），只改动受影响的 posting 行；
/// 也是删除日记时摘除 posting 的唯一依据。[contentChars] 供 BM25 长度归一的
/// 全局均值（SearchStats）做增量维护。
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
