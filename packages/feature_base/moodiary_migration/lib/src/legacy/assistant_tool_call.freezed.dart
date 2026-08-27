// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_tool_call.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssistantToolCall {

/// rig 生成的关联 id，用来把「开始」与「结果」两个事件配成一对。
 String get callId;/// 工具 id（与 `AssistantTool.id` 一致）。
 String get name;/// 模型传的入参，原样 JSON。
 String get argsJson;/// 工具返回的文本。[done] 为 false 时无意义。
 String get result;/// 是否已拿到结果。流式期间先是 false（转圈），拿到结果才置真。
 bool get done;
/// Create a copy of AssistantToolCall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantToolCallCopyWith<AssistantToolCall> get copyWith => _$AssistantToolCallCopyWithImpl<AssistantToolCall>(this as AssistantToolCall, _$identity);

  /// Serializes this AssistantToolCall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantToolCall&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.argsJson, argsJson) || other.argsJson == argsJson)&&(identical(other.result, result) || other.result == result)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,name,argsJson,result,done);

@override
String toString() {
  return 'AssistantToolCall(callId: $callId, name: $name, argsJson: $argsJson, result: $result, done: $done)';
}


}

/// @nodoc
abstract mixin class $AssistantToolCallCopyWith<$Res>  {
  factory $AssistantToolCallCopyWith(AssistantToolCall value, $Res Function(AssistantToolCall) _then) = _$AssistantToolCallCopyWithImpl;
@useResult
$Res call({
 String callId, String name, String argsJson, String result, bool done
});




}
/// @nodoc
class _$AssistantToolCallCopyWithImpl<$Res>
    implements $AssistantToolCallCopyWith<$Res> {
  _$AssistantToolCallCopyWithImpl(this._self, this._then);

  final AssistantToolCall _self;
  final $Res Function(AssistantToolCall) _then;

/// Create a copy of AssistantToolCall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? callId = null,Object? name = null,Object? argsJson = null,Object? result = null,Object? done = null,}) {
  return _then(AssistantToolCall(
callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,argsJson: null == argsJson ? _self.argsJson : argsJson // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantToolCall].
extension AssistantToolCallPatterns on AssistantToolCall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantToolCall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantToolCall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantToolCall value)  $default,){
final _that = this;
switch (_that) {
case _AssistantToolCall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantToolCall value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantToolCall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String callId,  String name,  String argsJson,  String result,  bool done)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantToolCall() when $default != null:
return $default(_that.callId,_that.name,_that.argsJson,_that.result,_that.done);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String callId,  String name,  String argsJson,  String result,  bool done)  $default,) {final _that = this;
switch (_that) {
case _AssistantToolCall():
return $default(_that.callId,_that.name,_that.argsJson,_that.result,_that.done);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String callId,  String name,  String argsJson,  String result,  bool done)?  $default,) {final _that = this;
switch (_that) {
case _AssistantToolCall() when $default != null:
return $default(_that.callId,_that.name,_that.argsJson,_that.result,_that.done);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssistantToolCall extends AssistantToolCall {
  const _AssistantToolCall({required this.callId, required this.name, this.argsJson = '', this.result = '', this.done = false}): super._();
  factory _AssistantToolCall.fromJson(Map<String, dynamic> json) => _$AssistantToolCallFromJson(json);

/// rig 生成的关联 id，用来把「开始」与「结果」两个事件配成一对。
@override final  String callId;
/// 工具 id（与 `AssistantTool.id` 一致）。
@override final  String name;
/// 模型传的入参，原样 JSON。
@override@JsonKey() final  String argsJson;
/// 工具返回的文本。[done] 为 false 时无意义。
@override@JsonKey() final  String result;
/// 是否已拿到结果。流式期间先是 false（转圈），拿到结果才置真。
@override@JsonKey() final  bool done;

/// Create a copy of AssistantToolCall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantToolCallCopyWith<_AssistantToolCall> get copyWith => __$AssistantToolCallCopyWithImpl<_AssistantToolCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantToolCallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantToolCall&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.argsJson, argsJson) || other.argsJson == argsJson)&&(identical(other.result, result) || other.result == result)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,name,argsJson,result,done);

@override
String toString() {
  return 'AssistantToolCall(callId: $callId, name: $name, argsJson: $argsJson, result: $result, done: $done)';
}


}

/// @nodoc
abstract mixin class _$AssistantToolCallCopyWith<$Res> implements $AssistantToolCallCopyWith<$Res> {
  factory _$AssistantToolCallCopyWith(_AssistantToolCall value, $Res Function(_AssistantToolCall) _then) = __$AssistantToolCallCopyWithImpl;
@override @useResult
$Res call({
 String callId, String name, String argsJson, String result, bool done
});




}
/// @nodoc
class __$AssistantToolCallCopyWithImpl<$Res>
    implements _$AssistantToolCallCopyWith<$Res> {
  __$AssistantToolCallCopyWithImpl(this._self, this._then);

  final _AssistantToolCall _self;
  final $Res Function(_AssistantToolCall) _then;

/// Create a copy of AssistantToolCall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? callId = null,Object? name = null,Object? argsJson = null,Object? result = null,Object? done = null,}) {
  return _then(_AssistantToolCall(
callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,argsJson: null == argsJson ? _self.argsJson : argsJson // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
