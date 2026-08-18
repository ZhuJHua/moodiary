// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_model_preset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LlmModelPreset {

 String get id; String get name;/// 这一款模型实际要走的协议。
 AssistantProviderType get protocol;/// 这一款模型实际要打的 baseUrl。空串表示走该协议官方端点。
 String get baseUrl; String get description; bool get toolCall; bool get reasoning; bool? get structuredOutput;/// 温度是否可调（gpt-5 一类是 false）。
 bool? get temperature;/// 思考控制能力。null = 目录没标；空列表 = 模型会思考但调用方无控制。
 List<ReasoningControl>? get reasoningOptions;/// 交错思考的回传字段名（`reasoning_content` / `reasoning_details`）。
 String? get interleavedField; int? get contextLimit;/// 最大输入 token。与 [contextLimit] 不是一回事：后者含输出。
 int? get inputLimit; int? get outputLimit; List<String> get inputModalities; num? get inputCost; num? get outputCost; num? get reasoningCost; num? get cacheReadCost; num? get cacheWriteCost; String? get releaseDate;/// `alpha` / `beta` / `deprecated`。null 表示正常在服。
 String? get status;
/// Create a copy of LlmModelPreset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmModelPresetCopyWith<LlmModelPreset> get copyWith => _$LlmModelPresetCopyWithImpl<LlmModelPreset>(this as LlmModelPreset, _$identity);

  /// Serializes this LlmModelPreset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmModelPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.structuredOutput, structuredOutput) || other.structuredOutput == structuredOutput)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&const DeepCollectionEquality().equals(other.reasoningOptions, reasoningOptions)&&(identical(other.interleavedField, interleavedField) || other.interleavedField == interleavedField)&&(identical(other.contextLimit, contextLimit) || other.contextLimit == contextLimit)&&(identical(other.inputLimit, inputLimit) || other.inputLimit == inputLimit)&&(identical(other.outputLimit, outputLimit) || other.outputLimit == outputLimit)&&const DeepCollectionEquality().equals(other.inputModalities, inputModalities)&&(identical(other.inputCost, inputCost) || other.inputCost == inputCost)&&(identical(other.outputCost, outputCost) || other.outputCost == outputCost)&&(identical(other.reasoningCost, reasoningCost) || other.reasoningCost == reasoningCost)&&(identical(other.cacheReadCost, cacheReadCost) || other.cacheReadCost == cacheReadCost)&&(identical(other.cacheWriteCost, cacheWriteCost) || other.cacheWriteCost == cacheWriteCost)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,protocol,baseUrl,description,toolCall,reasoning,structuredOutput,temperature,const DeepCollectionEquality().hash(reasoningOptions),interleavedField,contextLimit,inputLimit,outputLimit,const DeepCollectionEquality().hash(inputModalities),inputCost,outputCost,reasoningCost,cacheReadCost,cacheWriteCost,releaseDate,status]);

@override
String toString() {
  return 'LlmModelPreset(id: $id, name: $name, protocol: $protocol, baseUrl: $baseUrl, description: $description, toolCall: $toolCall, reasoning: $reasoning, structuredOutput: $structuredOutput, temperature: $temperature, reasoningOptions: $reasoningOptions, interleavedField: $interleavedField, contextLimit: $contextLimit, inputLimit: $inputLimit, outputLimit: $outputLimit, inputModalities: $inputModalities, inputCost: $inputCost, outputCost: $outputCost, reasoningCost: $reasoningCost, cacheReadCost: $cacheReadCost, cacheWriteCost: $cacheWriteCost, releaseDate: $releaseDate, status: $status)';
}


}

/// @nodoc
abstract mixin class $LlmModelPresetCopyWith<$Res>  {
  factory $LlmModelPresetCopyWith(LlmModelPreset value, $Res Function(LlmModelPreset) _then) = _$LlmModelPresetCopyWithImpl;
@useResult
$Res call({
 String id, String name, AssistantProviderType protocol, String baseUrl, String description, bool toolCall, bool reasoning, bool? structuredOutput, bool? temperature, List<ReasoningControl>? reasoningOptions, String? interleavedField, int? contextLimit, int? inputLimit, int? outputLimit, List<String> inputModalities, num? inputCost, num? outputCost, num? reasoningCost, num? cacheReadCost, num? cacheWriteCost, String? releaseDate, String? status
});




}
/// @nodoc
class _$LlmModelPresetCopyWithImpl<$Res>
    implements $LlmModelPresetCopyWith<$Res> {
  _$LlmModelPresetCopyWithImpl(this._self, this._then);

  final LlmModelPreset _self;
  final $Res Function(LlmModelPreset) _then;

/// Create a copy of LlmModelPreset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? protocol = null,Object? baseUrl = null,Object? description = null,Object? toolCall = null,Object? reasoning = null,Object? structuredOutput = freezed,Object? temperature = freezed,Object? reasoningOptions = freezed,Object? interleavedField = freezed,Object? contextLimit = freezed,Object? inputLimit = freezed,Object? outputLimit = freezed,Object? inputModalities = null,Object? inputCost = freezed,Object? outputCost = freezed,Object? reasoningCost = freezed,Object? cacheReadCost = freezed,Object? cacheWriteCost = freezed,Object? releaseDate = freezed,Object? status = freezed,}) {
  return _then(LlmModelPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,structuredOutput: freezed == structuredOutput ? _self.structuredOutput : structuredOutput // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as bool?,reasoningOptions: freezed == reasoningOptions ? _self.reasoningOptions : reasoningOptions // ignore: cast_nullable_to_non_nullable
as List<ReasoningControl>?,interleavedField: freezed == interleavedField ? _self.interleavedField : interleavedField // ignore: cast_nullable_to_non_nullable
as String?,contextLimit: freezed == contextLimit ? _self.contextLimit : contextLimit // ignore: cast_nullable_to_non_nullable
as int?,inputLimit: freezed == inputLimit ? _self.inputLimit : inputLimit // ignore: cast_nullable_to_non_nullable
as int?,outputLimit: freezed == outputLimit ? _self.outputLimit : outputLimit // ignore: cast_nullable_to_non_nullable
as int?,inputModalities: null == inputModalities ? _self.inputModalities : inputModalities // ignore: cast_nullable_to_non_nullable
as List<String>,inputCost: freezed == inputCost ? _self.inputCost : inputCost // ignore: cast_nullable_to_non_nullable
as num?,outputCost: freezed == outputCost ? _self.outputCost : outputCost // ignore: cast_nullable_to_non_nullable
as num?,reasoningCost: freezed == reasoningCost ? _self.reasoningCost : reasoningCost // ignore: cast_nullable_to_non_nullable
as num?,cacheReadCost: freezed == cacheReadCost ? _self.cacheReadCost : cacheReadCost // ignore: cast_nullable_to_non_nullable
as num?,cacheWriteCost: freezed == cacheWriteCost ? _self.cacheWriteCost : cacheWriteCost // ignore: cast_nullable_to_non_nullable
as num?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmModelPreset].
extension LlmModelPresetPatterns on LlmModelPreset {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmModelPreset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmModelPreset value)  $default,){
final _that = this;
switch (_that) {
case _LlmModelPreset():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmModelPreset value)?  $default,){
final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  String description,  bool toolCall,  bool reasoning,  bool? structuredOutput,  bool? temperature,  List<ReasoningControl>? reasoningOptions,  String? interleavedField,  int? contextLimit,  int? inputLimit,  int? outputLimit,  List<String> inputModalities,  num? inputCost,  num? outputCost,  num? reasoningCost,  num? cacheReadCost,  num? cacheWriteCost,  String? releaseDate,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.description,_that.toolCall,_that.reasoning,_that.structuredOutput,_that.temperature,_that.reasoningOptions,_that.interleavedField,_that.contextLimit,_that.inputLimit,_that.outputLimit,_that.inputModalities,_that.inputCost,_that.outputCost,_that.reasoningCost,_that.cacheReadCost,_that.cacheWriteCost,_that.releaseDate,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  String description,  bool toolCall,  bool reasoning,  bool? structuredOutput,  bool? temperature,  List<ReasoningControl>? reasoningOptions,  String? interleavedField,  int? contextLimit,  int? inputLimit,  int? outputLimit,  List<String> inputModalities,  num? inputCost,  num? outputCost,  num? reasoningCost,  num? cacheReadCost,  num? cacheWriteCost,  String? releaseDate,  String? status)  $default,) {final _that = this;
switch (_that) {
case _LlmModelPreset():
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.description,_that.toolCall,_that.reasoning,_that.structuredOutput,_that.temperature,_that.reasoningOptions,_that.interleavedField,_that.contextLimit,_that.inputLimit,_that.outputLimit,_that.inputModalities,_that.inputCost,_that.outputCost,_that.reasoningCost,_that.cacheReadCost,_that.cacheWriteCost,_that.releaseDate,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  String description,  bool toolCall,  bool reasoning,  bool? structuredOutput,  bool? temperature,  List<ReasoningControl>? reasoningOptions,  String? interleavedField,  int? contextLimit,  int? inputLimit,  int? outputLimit,  List<String> inputModalities,  num? inputCost,  num? outputCost,  num? reasoningCost,  num? cacheReadCost,  num? cacheWriteCost,  String? releaseDate,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.description,_that.toolCall,_that.reasoning,_that.structuredOutput,_that.temperature,_that.reasoningOptions,_that.interleavedField,_that.contextLimit,_that.inputLimit,_that.outputLimit,_that.inputModalities,_that.inputCost,_that.outputCost,_that.reasoningCost,_that.cacheReadCost,_that.cacheWriteCost,_that.releaseDate,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmModelPreset extends LlmModelPreset {
  const _LlmModelPreset({required this.id, required this.name, required this.protocol, required this.baseUrl, this.description = '', this.toolCall = false, this.reasoning = false, this.structuredOutput, this.temperature,  List<ReasoningControl>? reasoningOptions, this.interleavedField, this.contextLimit, this.inputLimit, this.outputLimit,  List<String> inputModalities = const <String>[], this.inputCost, this.outputCost, this.reasoningCost, this.cacheReadCost, this.cacheWriteCost, this.releaseDate, this.status}): _reasoningOptions = reasoningOptions,_inputModalities = inputModalities,super._();
  factory _LlmModelPreset.fromJson(Map<String, dynamic> json) => _$LlmModelPresetFromJson(json);

@override final  String id;
@override final  String name;
/// 这一款模型实际要走的协议。
@override final  AssistantProviderType protocol;
/// 这一款模型实际要打的 baseUrl。空串表示走该协议官方端点。
@override final  String baseUrl;
@override@JsonKey() final  String description;
@override@JsonKey() final  bool toolCall;
@override@JsonKey() final  bool reasoning;
@override final  bool? structuredOutput;
/// 温度是否可调（gpt-5 一类是 false）。
@override final  bool? temperature;
/// 思考控制能力。null = 目录没标；空列表 = 模型会思考但调用方无控制。
 final  List<ReasoningControl>? _reasoningOptions;
/// 思考控制能力。null = 目录没标；空列表 = 模型会思考但调用方无控制。
@override List<ReasoningControl>? get reasoningOptions {
  final value = _reasoningOptions;
  if (value == null) return null;
  if (_reasoningOptions is EqualUnmodifiableListView) return _reasoningOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// 交错思考的回传字段名（`reasoning_content` / `reasoning_details`）。
@override final  String? interleavedField;
@override final  int? contextLimit;
/// 最大输入 token。与 [contextLimit] 不是一回事：后者含输出。
@override final  int? inputLimit;
@override final  int? outputLimit;
 final  List<String> _inputModalities;
@override@JsonKey() List<String> get inputModalities {
  if (_inputModalities is EqualUnmodifiableListView) return _inputModalities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inputModalities);
}

@override final  num? inputCost;
@override final  num? outputCost;
@override final  num? reasoningCost;
@override final  num? cacheReadCost;
@override final  num? cacheWriteCost;
@override final  String? releaseDate;
/// `alpha` / `beta` / `deprecated`。null 表示正常在服。
@override final  String? status;

/// Create a copy of LlmModelPreset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmModelPresetCopyWith<_LlmModelPreset> get copyWith => __$LlmModelPresetCopyWithImpl<_LlmModelPreset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmModelPresetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmModelPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.structuredOutput, structuredOutput) || other.structuredOutput == structuredOutput)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&const DeepCollectionEquality().equals(other._reasoningOptions, _reasoningOptions)&&(identical(other.interleavedField, interleavedField) || other.interleavedField == interleavedField)&&(identical(other.contextLimit, contextLimit) || other.contextLimit == contextLimit)&&(identical(other.inputLimit, inputLimit) || other.inputLimit == inputLimit)&&(identical(other.outputLimit, outputLimit) || other.outputLimit == outputLimit)&&const DeepCollectionEquality().equals(other._inputModalities, _inputModalities)&&(identical(other.inputCost, inputCost) || other.inputCost == inputCost)&&(identical(other.outputCost, outputCost) || other.outputCost == outputCost)&&(identical(other.reasoningCost, reasoningCost) || other.reasoningCost == reasoningCost)&&(identical(other.cacheReadCost, cacheReadCost) || other.cacheReadCost == cacheReadCost)&&(identical(other.cacheWriteCost, cacheWriteCost) || other.cacheWriteCost == cacheWriteCost)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,protocol,baseUrl,description,toolCall,reasoning,structuredOutput,temperature,const DeepCollectionEquality().hash(_reasoningOptions),interleavedField,contextLimit,inputLimit,outputLimit,const DeepCollectionEquality().hash(_inputModalities),inputCost,outputCost,reasoningCost,cacheReadCost,cacheWriteCost,releaseDate,status]);

@override
String toString() {
  return 'LlmModelPreset(id: $id, name: $name, protocol: $protocol, baseUrl: $baseUrl, description: $description, toolCall: $toolCall, reasoning: $reasoning, structuredOutput: $structuredOutput, temperature: $temperature, reasoningOptions: $reasoningOptions, interleavedField: $interleavedField, contextLimit: $contextLimit, inputLimit: $inputLimit, outputLimit: $outputLimit, inputModalities: $inputModalities, inputCost: $inputCost, outputCost: $outputCost, reasoningCost: $reasoningCost, cacheReadCost: $cacheReadCost, cacheWriteCost: $cacheWriteCost, releaseDate: $releaseDate, status: $status)';
}


}

/// @nodoc
abstract mixin class _$LlmModelPresetCopyWith<$Res> implements $LlmModelPresetCopyWith<$Res> {
  factory _$LlmModelPresetCopyWith(_LlmModelPreset value, $Res Function(_LlmModelPreset) _then) = __$LlmModelPresetCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AssistantProviderType protocol, String baseUrl, String description, bool toolCall, bool reasoning, bool? structuredOutput, bool? temperature, List<ReasoningControl>? reasoningOptions, String? interleavedField, int? contextLimit, int? inputLimit, int? outputLimit, List<String> inputModalities, num? inputCost, num? outputCost, num? reasoningCost, num? cacheReadCost, num? cacheWriteCost, String? releaseDate, String? status
});




}
/// @nodoc
class __$LlmModelPresetCopyWithImpl<$Res>
    implements _$LlmModelPresetCopyWith<$Res> {
  __$LlmModelPresetCopyWithImpl(this._self, this._then);

  final _LlmModelPreset _self;
  final $Res Function(_LlmModelPreset) _then;

/// Create a copy of LlmModelPreset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? protocol = null,Object? baseUrl = null,Object? description = null,Object? toolCall = null,Object? reasoning = null,Object? structuredOutput = freezed,Object? temperature = freezed,Object? reasoningOptions = freezed,Object? interleavedField = freezed,Object? contextLimit = freezed,Object? inputLimit = freezed,Object? outputLimit = freezed,Object? inputModalities = null,Object? inputCost = freezed,Object? outputCost = freezed,Object? reasoningCost = freezed,Object? cacheReadCost = freezed,Object? cacheWriteCost = freezed,Object? releaseDate = freezed,Object? status = freezed,}) {
  return _then(_LlmModelPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,structuredOutput: freezed == structuredOutput ? _self.structuredOutput : structuredOutput // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as bool?,reasoningOptions: freezed == reasoningOptions ? _self._reasoningOptions : reasoningOptions // ignore: cast_nullable_to_non_nullable
as List<ReasoningControl>?,interleavedField: freezed == interleavedField ? _self.interleavedField : interleavedField // ignore: cast_nullable_to_non_nullable
as String?,contextLimit: freezed == contextLimit ? _self.contextLimit : contextLimit // ignore: cast_nullable_to_non_nullable
as int?,inputLimit: freezed == inputLimit ? _self.inputLimit : inputLimit // ignore: cast_nullable_to_non_nullable
as int?,outputLimit: freezed == outputLimit ? _self.outputLimit : outputLimit // ignore: cast_nullable_to_non_nullable
as int?,inputModalities: null == inputModalities ? _self._inputModalities : inputModalities // ignore: cast_nullable_to_non_nullable
as List<String>,inputCost: freezed == inputCost ? _self.inputCost : inputCost // ignore: cast_nullable_to_non_nullable
as num?,outputCost: freezed == outputCost ? _self.outputCost : outputCost // ignore: cast_nullable_to_non_nullable
as num?,reasoningCost: freezed == reasoningCost ? _self.reasoningCost : reasoningCost // ignore: cast_nullable_to_non_nullable
as num?,cacheReadCost: freezed == cacheReadCost ? _self.cacheReadCost : cacheReadCost // ignore: cast_nullable_to_non_nullable
as num?,cacheWriteCost: freezed == cacheWriteCost ? _self.cacheWriteCost : cacheWriteCost // ignore: cast_nullable_to_non_nullable
as num?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
