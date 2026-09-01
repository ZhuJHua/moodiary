// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reasoning_control.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReasoningControl _$ReasoningControlFromJson(Map<String, dynamic> json) =>
    _ReasoningControl(
      type: $enumDecode(_$ReasoningControlTypeEnumMap, json['type']),
      values:
          (json['values'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      min: (json['min'] as num?)?.toInt(),
      max: (json['max'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ReasoningControlToJson(_ReasoningControl instance) =>
    <String, dynamic>{
      'type': _$ReasoningControlTypeEnumMap[instance.type]!,
      'values': instance.values,
      'min': instance.min,
      'max': instance.max,
    };

const _$ReasoningControlTypeEnumMap = {
  ReasoningControlType.toggle: 'toggle',
  ReasoningControlType.effort: 'effort',
  ReasoningControlType.budgetTokens: 'budgetTokens',
};
