import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'reindex_queue.freezed.dart';
part 'reindex_queue.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class ReindexQueue with _$ReindexQueue {
  const factory ReindexQueue({@Id() required int diaryIsarId}) = _ReindexQueue;

  const ReindexQueue._();
}
