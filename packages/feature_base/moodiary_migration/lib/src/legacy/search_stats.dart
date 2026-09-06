import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'search_stats.freezed.dart';
part 'search_stats.g.dart';

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
