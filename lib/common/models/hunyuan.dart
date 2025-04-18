import 'package:freezed_annotation/freezed_annotation.dart';

part 'hunyuan.freezed.dart';
part 'hunyuan.g.dart';

@freezed
abstract class PublicHeader with _$PublicHeader {
  const factory PublicHeader({
    @JsonKey(name: 'X-TC-Action') String? action,
    @JsonKey(name: 'X-TC-Timestamp') int? timestamp,
    @JsonKey(name: 'X-TC-Version') String? version,
    @JsonKey(name: 'Authorization') String? authorization,
  }) = _PublicHeader;

  factory PublicHeader.fromJson(Map<String, dynamic> json) =>
      _$PublicHeaderFromJson(json);
}

@freezed
abstract class Message with _$Message {
  const factory Message({
    @JsonKey(name: 'Role') required String role,
    @JsonKey(name: 'Content') required String content,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

@freezed
abstract class HunyuanResponse with _$HunyuanResponse {
  const factory HunyuanResponse({
    @JsonKey(name: 'Note') String? note,
    @JsonKey(name: 'Choices') List<Choices>? choices,
    @JsonKey(name: 'Created') int? created,
    @JsonKey(name: 'Id') String? id,
    @JsonKey(name: 'Usage') Usage? usage,
  }) = _HunyuanResponse;

  factory HunyuanResponse.fromJson(Map<String, dynamic> json) =>
      _$HunyuanResponseFromJson(json);
}

@freezed
abstract class Usage with _$Usage {
  const factory Usage({
    @JsonKey(name: 'PromptTokens') int? promptTokens,
    @JsonKey(name: 'CompletionTokens') int? completionTokens,
    @JsonKey(name: 'TotalTokens') int? totalTokens,
  }) = _Usage;

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
}

@freezed
abstract class Choices with _$Choices {
  const factory Choices({
    @JsonKey(name: 'FinishReason') String? finishReason,
    @JsonKey(name: 'Delta') Delta? delta,
  }) = _Choices;

  factory Choices.fromJson(Map<String, dynamic> json) =>
      _$ChoicesFromJson(json);
}

@freezed
abstract class Delta with _$Delta {
  const factory Delta({
    @JsonKey(name: 'Role') String? role,
    @JsonKey(name: 'Content') String? content,
  }) = _Delta;

  factory Delta.fromJson(Map<String, dynamic> json) => _$DeltaFromJson(json);
}
