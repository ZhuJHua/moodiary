import 'package:freezed_annotation/freezed_annotation.dart';

part 'hitokoto.freezed.dart';
part 'hitokoto.g.dart';

@freezed
abstract class HitokotoResponse with _$HitokotoResponse {
  const factory HitokotoResponse({
    int? id,
    String? uuid,
    String? hitokoto,
    String? type,
    String? from,
    @JsonKey(name: 'from_who') String? fromWho,
    String? creator,
    @JsonKey(name: 'creator_uid') int? creatorUid,
    int? reviewer,
    @JsonKey(name: 'commit_from') String? commitFrom,
    @JsonKey(name: 'created_at') String? createdAt,
    int? length,
  }) = _HitokotoResponse;

  factory HitokotoResponse.fromJson(Map<String, dynamic> json) =>
      _$HitokotoResponseFromJson(json);
}
