import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'reindex_queue.freezed.dart';
part 'reindex_queue.g.dart';

/// 待重建搜索 / 链接索引的日记队列（持久化）。编辑期自动保存只写日记行 + 入队，分词与
/// 倒排索引推迟到「关闭编辑器」或「下次启动恢复」时统一排空。
///
/// [diaryIsarId] 即 [Id]：入队幂等（同一篇重复编辑只占一条），出队按 id 删。崩溃/被杀时
/// 队列残留即「待索引」的持久标记，下次启动排空兜底，故搜索索引不会静默陈旧。
@freezed
@Collection(ignore: {'copyWith'})
abstract class ReindexQueue with _$ReindexQueue {
  const factory ReindexQueue({@Id() required int diaryIsarId}) = _ReindexQueue;

  const ReindexQueue._();
}
