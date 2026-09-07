import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'search_posting.freezed.dart';
part 'search_posting.g.dart';

enum TokenSource { cut, cutForSearch, title }

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
