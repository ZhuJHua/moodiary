// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hunyuan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicHeader _$PublicHeaderFromJson(Map<String, dynamic> json) =>
    _PublicHeader(
      action: json['X-TC-Action'] as String?,
      timestamp: (json['X-TC-Timestamp'] as num?)?.toInt(),
      version: json['X-TC-Version'] as String?,
      authorization: json['Authorization'] as String?,
    );

Map<String, dynamic> _$PublicHeaderToJson(_PublicHeader instance) =>
    <String, dynamic>{
      if (instance.action case final value?) 'X-TC-Action': value,
      if (instance.timestamp case final value?) 'X-TC-Timestamp': value,
      if (instance.version case final value?) 'X-TC-Version': value,
      if (instance.authorization case final value?) 'Authorization': value,
    };

_Message _$MessageFromJson(Map<String, dynamic> json) =>
    _Message(role: json['Role'] as String, content: json['Content'] as String);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'Role': instance.role,
  'Content': instance.content,
};

_HunyuanResponse _$HunyuanResponseFromJson(Map<String, dynamic> json) =>
    _HunyuanResponse(
      note: json['Note'] as String?,
      choices:
          (json['Choices'] as List<dynamic>?)
              ?.map((e) => Choices.fromJson(e as Map<String, dynamic>))
              .toList(),
      created: (json['Created'] as num?)?.toInt(),
      id: json['Id'] as String?,
      usage:
          json['Usage'] == null
              ? null
              : Usage.fromJson(json['Usage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HunyuanResponseToJson(_HunyuanResponse instance) =>
    <String, dynamic>{
      if (instance.note case final value?) 'Note': value,
      if (instance.choices case final value?) 'Choices': value,
      if (instance.created case final value?) 'Created': value,
      if (instance.id case final value?) 'Id': value,
      if (instance.usage case final value?) 'Usage': value,
    };

_Usage _$UsageFromJson(Map<String, dynamic> json) => _Usage(
  promptTokens: (json['PromptTokens'] as num?)?.toInt(),
  completionTokens: (json['CompletionTokens'] as num?)?.toInt(),
  totalTokens: (json['TotalTokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$UsageToJson(_Usage instance) => <String, dynamic>{
  if (instance.promptTokens case final value?) 'PromptTokens': value,
  if (instance.completionTokens case final value?) 'CompletionTokens': value,
  if (instance.totalTokens case final value?) 'TotalTokens': value,
};

_Choices _$ChoicesFromJson(Map<String, dynamic> json) => _Choices(
  finishReason: json['FinishReason'] as String?,
  delta:
      json['Delta'] == null
          ? null
          : Delta.fromJson(json['Delta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChoicesToJson(_Choices instance) => <String, dynamic>{
  if (instance.finishReason case final value?) 'FinishReason': value,
  if (instance.delta case final value?) 'Delta': value,
};

_Delta _$DeltaFromJson(Map<String, dynamic> json) =>
    _Delta(role: json['Role'] as String?, content: json['Content'] as String?);

Map<String, dynamic> _$DeltaToJson(_Delta instance) => <String, dynamic>{
  if (instance.role case final value?) 'Role': value,
  if (instance.content case final value?) 'Content': value,
};
