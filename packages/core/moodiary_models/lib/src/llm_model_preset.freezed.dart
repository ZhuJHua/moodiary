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

 String get id; String get name; bool get toolCall; bool get reasoning; bool get attachment; int? get contextLimit; int? get outputLimit; num? get inputCost; num? get outputCost; String? get releaseDate;
/// Create a copy of LlmModelPreset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmModelPresetCopyWith<LlmModelPreset> get copyWith => _$LlmModelPresetCopyWithImpl<LlmModelPreset>(this as LlmModelPreset, _$identity);

  /// Serializes this LlmModelPreset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmModelPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.attachment, attachment) || other.attachment == attachment)&&(identical(other.contextLimit, contextLimit) || other.contextLimit == contextLimit)&&(identical(other.outputLimit, outputLimit) || other.outputLimit == outputLimit)&&(identical(other.inputCost, inputCost) || other.inputCost == inputCost)&&(identical(other.outputCost, outputCost) || other.outputCost == outputCost)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,toolCall,reasoning,attachment,contextLimit,outputLimit,inputCost,outputCost,releaseDate);

@override
String toString() {
  return 'LlmModelPreset(id: $id, name: $name, toolCall: $toolCall, reasoning: $reasoning, attachment: $attachment, contextLimit: $contextLimit, outputLimit: $outputLimit, inputCost: $inputCost, outputCost: $outputCost, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class $LlmModelPresetCopyWith<$Res>  {
  factory $LlmModelPresetCopyWith(LlmModelPreset value, $Res Function(LlmModelPreset) _then) = _$LlmModelPresetCopyWithImpl;
@useResult
$Res call({
 String id, String name, bool toolCall, bool reasoning, bool attachment, int? contextLimit, int? outputLimit, num? inputCost, num? outputCost, String? releaseDate
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? toolCall = null,Object? reasoning = null,Object? attachment = null,Object? contextLimit = freezed,Object? outputLimit = freezed,Object? inputCost = freezed,Object? outputCost = freezed,Object? releaseDate = freezed,}) {
  return _then(LlmModelPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as bool,contextLimit: freezed == contextLimit ? _self.contextLimit : contextLimit // ignore: cast_nullable_to_non_nullable
as int?,outputLimit: freezed == outputLimit ? _self.outputLimit : outputLimit // ignore: cast_nullable_to_non_nullable
as int?,inputCost: freezed == inputCost ? _self.inputCost : inputCost // ignore: cast_nullable_to_non_nullable
as num?,outputCost: freezed == outputCost ? _self.outputCost : outputCost // ignore: cast_nullable_to_non_nullable
as num?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  bool toolCall,  bool reasoning,  bool attachment,  int? contextLimit,  int? outputLimit,  num? inputCost,  num? outputCost,  String? releaseDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that.id,_that.name,_that.toolCall,_that.reasoning,_that.attachment,_that.contextLimit,_that.outputLimit,_that.inputCost,_that.outputCost,_that.releaseDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  bool toolCall,  bool reasoning,  bool attachment,  int? contextLimit,  int? outputLimit,  num? inputCost,  num? outputCost,  String? releaseDate)  $default,) {final _that = this;
switch (_that) {
case _LlmModelPreset():
return $default(_that.id,_that.name,_that.toolCall,_that.reasoning,_that.attachment,_that.contextLimit,_that.outputLimit,_that.inputCost,_that.outputCost,_that.releaseDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  bool toolCall,  bool reasoning,  bool attachment,  int? contextLimit,  int? outputLimit,  num? inputCost,  num? outputCost,  String? releaseDate)?  $default,) {final _that = this;
switch (_that) {
case _LlmModelPreset() when $default != null:
return $default(_that.id,_that.name,_that.toolCall,_that.reasoning,_that.attachment,_that.contextLimit,_that.outputLimit,_that.inputCost,_that.outputCost,_that.releaseDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmModelPreset extends LlmModelPreset {
  const _LlmModelPreset({required this.id, required this.name, this.toolCall = false, this.reasoning = false, this.attachment = false, this.contextLimit, this.outputLimit, this.inputCost, this.outputCost, this.releaseDate}): super._();
  factory _LlmModelPreset.fromJson(Map<String, dynamic> json) => _$LlmModelPresetFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  bool toolCall;
@override@JsonKey() final  bool reasoning;
@override@JsonKey() final  bool attachment;
@override final  int? contextLimit;
@override final  int? outputLimit;
@override final  num? inputCost;
@override final  num? outputCost;
@override final  String? releaseDate;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmModelPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.attachment, attachment) || other.attachment == attachment)&&(identical(other.contextLimit, contextLimit) || other.contextLimit == contextLimit)&&(identical(other.outputLimit, outputLimit) || other.outputLimit == outputLimit)&&(identical(other.inputCost, inputCost) || other.inputCost == inputCost)&&(identical(other.outputCost, outputCost) || other.outputCost == outputCost)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,toolCall,reasoning,attachment,contextLimit,outputLimit,inputCost,outputCost,releaseDate);

@override
String toString() {
  return 'LlmModelPreset(id: $id, name: $name, toolCall: $toolCall, reasoning: $reasoning, attachment: $attachment, contextLimit: $contextLimit, outputLimit: $outputLimit, inputCost: $inputCost, outputCost: $outputCost, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class _$LlmModelPresetCopyWith<$Res> implements $LlmModelPresetCopyWith<$Res> {
  factory _$LlmModelPresetCopyWith(_LlmModelPreset value, $Res Function(_LlmModelPreset) _then) = __$LlmModelPresetCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, bool toolCall, bool reasoning, bool attachment, int? contextLimit, int? outputLimit, num? inputCost, num? outputCost, String? releaseDate
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? toolCall = null,Object? reasoning = null,Object? attachment = null,Object? contextLimit = freezed,Object? outputLimit = freezed,Object? inputCost = freezed,Object? outputCost = freezed,Object? releaseDate = freezed,}) {
  return _then(_LlmModelPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as bool,contextLimit: freezed == contextLimit ? _self.contextLimit : contextLimit // ignore: cast_nullable_to_non_nullable
as int?,outputLimit: freezed == outputLimit ? _self.outputLimit : outputLimit // ignore: cast_nullable_to_non_nullable
as int?,inputCost: freezed == inputCost ? _self.inputCost : inputCost // ignore: cast_nullable_to_non_nullable
as num?,outputCost: freezed == outputCost ? _self.outputCost : outputCost // ignore: cast_nullable_to_non_nullable
as num?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
