// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RigStreamEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RigStreamEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RigStreamEvent()';
}


}

/// @nodoc
class $RigStreamEventCopyWith<$Res>  {
$RigStreamEventCopyWith(RigStreamEvent _, $Res Function(RigStreamEvent) __);
}


/// Adds pattern-matching-related methods to [RigStreamEvent].
extension RigStreamEventPatterns on RigStreamEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RigStreamEvent_TextDelta value)?  textDelta,TResult Function( RigStreamEvent_ReasoningDelta value)?  reasoningDelta,TResult Function( RigStreamEvent_ToolCall value)?  toolCall,TResult Function( RigStreamEvent_Usage value)?  usage,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta() when textDelta != null:
return textDelta(_that);case RigStreamEvent_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case RigStreamEvent_ToolCall() when toolCall != null:
return toolCall(_that);case RigStreamEvent_Usage() when usage != null:
return usage(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RigStreamEvent_TextDelta value)  textDelta,required TResult Function( RigStreamEvent_ReasoningDelta value)  reasoningDelta,required TResult Function( RigStreamEvent_ToolCall value)  toolCall,required TResult Function( RigStreamEvent_Usage value)  usage,}){
final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta():
return textDelta(_that);case RigStreamEvent_ReasoningDelta():
return reasoningDelta(_that);case RigStreamEvent_ToolCall():
return toolCall(_that);case RigStreamEvent_Usage():
return usage(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RigStreamEvent_TextDelta value)?  textDelta,TResult? Function( RigStreamEvent_ReasoningDelta value)?  reasoningDelta,TResult? Function( RigStreamEvent_ToolCall value)?  toolCall,TResult? Function( RigStreamEvent_Usage value)?  usage,}){
final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta() when textDelta != null:
return textDelta(_that);case RigStreamEvent_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case RigStreamEvent_ToolCall() when toolCall != null:
return toolCall(_that);case RigStreamEvent_Usage() when usage != null:
return usage(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  textDelta,TResult Function( String field0)?  reasoningDelta,TResult Function( String field0)?  toolCall,TResult Function( int inputTokens,  int outputTokens)?  usage,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta() when textDelta != null:
return textDelta(_that.field0);case RigStreamEvent_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.field0);case RigStreamEvent_ToolCall() when toolCall != null:
return toolCall(_that.field0);case RigStreamEvent_Usage() when usage != null:
return usage(_that.inputTokens,_that.outputTokens);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  textDelta,required TResult Function( String field0)  reasoningDelta,required TResult Function( String field0)  toolCall,required TResult Function( int inputTokens,  int outputTokens)  usage,}) {final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta():
return textDelta(_that.field0);case RigStreamEvent_ReasoningDelta():
return reasoningDelta(_that.field0);case RigStreamEvent_ToolCall():
return toolCall(_that.field0);case RigStreamEvent_Usage():
return usage(_that.inputTokens,_that.outputTokens);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  textDelta,TResult? Function( String field0)?  reasoningDelta,TResult? Function( String field0)?  toolCall,TResult? Function( int inputTokens,  int outputTokens)?  usage,}) {final _that = this;
switch (_that) {
case RigStreamEvent_TextDelta() when textDelta != null:
return textDelta(_that.field0);case RigStreamEvent_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.field0);case RigStreamEvent_ToolCall() when toolCall != null:
return toolCall(_that.field0);case RigStreamEvent_Usage() when usage != null:
return usage(_that.inputTokens,_that.outputTokens);case _:
  return null;

}
}

}

/// @nodoc


class RigStreamEvent_TextDelta extends RigStreamEvent {
  const RigStreamEvent_TextDelta(this.field0): super._();
  

 final  String field0;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RigStreamEvent_TextDeltaCopyWith<RigStreamEvent_TextDelta> get copyWith => _$RigStreamEvent_TextDeltaCopyWithImpl<RigStreamEvent_TextDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RigStreamEvent_TextDelta&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RigStreamEvent.textDelta(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RigStreamEvent_TextDeltaCopyWith<$Res> implements $RigStreamEventCopyWith<$Res> {
  factory $RigStreamEvent_TextDeltaCopyWith(RigStreamEvent_TextDelta value, $Res Function(RigStreamEvent_TextDelta) _then) = _$RigStreamEvent_TextDeltaCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RigStreamEvent_TextDeltaCopyWithImpl<$Res>
    implements $RigStreamEvent_TextDeltaCopyWith<$Res> {
  _$RigStreamEvent_TextDeltaCopyWithImpl(this._self, this._then);

  final RigStreamEvent_TextDelta _self;
  final $Res Function(RigStreamEvent_TextDelta) _then;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RigStreamEvent_TextDelta(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RigStreamEvent_ReasoningDelta extends RigStreamEvent {
  const RigStreamEvent_ReasoningDelta(this.field0): super._();
  

 final  String field0;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RigStreamEvent_ReasoningDeltaCopyWith<RigStreamEvent_ReasoningDelta> get copyWith => _$RigStreamEvent_ReasoningDeltaCopyWithImpl<RigStreamEvent_ReasoningDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RigStreamEvent_ReasoningDelta&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RigStreamEvent.reasoningDelta(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RigStreamEvent_ReasoningDeltaCopyWith<$Res> implements $RigStreamEventCopyWith<$Res> {
  factory $RigStreamEvent_ReasoningDeltaCopyWith(RigStreamEvent_ReasoningDelta value, $Res Function(RigStreamEvent_ReasoningDelta) _then) = _$RigStreamEvent_ReasoningDeltaCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RigStreamEvent_ReasoningDeltaCopyWithImpl<$Res>
    implements $RigStreamEvent_ReasoningDeltaCopyWith<$Res> {
  _$RigStreamEvent_ReasoningDeltaCopyWithImpl(this._self, this._then);

  final RigStreamEvent_ReasoningDelta _self;
  final $Res Function(RigStreamEvent_ReasoningDelta) _then;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RigStreamEvent_ReasoningDelta(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RigStreamEvent_ToolCall extends RigStreamEvent {
  const RigStreamEvent_ToolCall(this.field0): super._();
  

 final  String field0;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RigStreamEvent_ToolCallCopyWith<RigStreamEvent_ToolCall> get copyWith => _$RigStreamEvent_ToolCallCopyWithImpl<RigStreamEvent_ToolCall>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RigStreamEvent_ToolCall&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RigStreamEvent.toolCall(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RigStreamEvent_ToolCallCopyWith<$Res> implements $RigStreamEventCopyWith<$Res> {
  factory $RigStreamEvent_ToolCallCopyWith(RigStreamEvent_ToolCall value, $Res Function(RigStreamEvent_ToolCall) _then) = _$RigStreamEvent_ToolCallCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RigStreamEvent_ToolCallCopyWithImpl<$Res>
    implements $RigStreamEvent_ToolCallCopyWith<$Res> {
  _$RigStreamEvent_ToolCallCopyWithImpl(this._self, this._then);

  final RigStreamEvent_ToolCall _self;
  final $Res Function(RigStreamEvent_ToolCall) _then;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RigStreamEvent_ToolCall(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RigStreamEvent_Usage extends RigStreamEvent {
  const RigStreamEvent_Usage({required this.inputTokens, required this.outputTokens}): super._();
  

 final  int inputTokens;
 final  int outputTokens;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RigStreamEvent_UsageCopyWith<RigStreamEvent_Usage> get copyWith => _$RigStreamEvent_UsageCopyWithImpl<RigStreamEvent_Usage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RigStreamEvent_Usage&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens));
}


@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens);

@override
String toString() {
  return 'RigStreamEvent.usage(inputTokens: $inputTokens, outputTokens: $outputTokens)';
}


}

/// @nodoc
abstract mixin class $RigStreamEvent_UsageCopyWith<$Res> implements $RigStreamEventCopyWith<$Res> {
  factory $RigStreamEvent_UsageCopyWith(RigStreamEvent_Usage value, $Res Function(RigStreamEvent_Usage) _then) = _$RigStreamEvent_UsageCopyWithImpl;
@useResult
$Res call({
 int inputTokens, int outputTokens
});




}
/// @nodoc
class _$RigStreamEvent_UsageCopyWithImpl<$Res>
    implements $RigStreamEvent_UsageCopyWith<$Res> {
  _$RigStreamEvent_UsageCopyWithImpl(this._self, this._then);

  final RigStreamEvent_Usage _self;
  final $Res Function(RigStreamEvent_Usage) _then;

/// Create a copy of RigStreamEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? inputTokens = null,Object? outputTokens = null,}) {
  return _then(RigStreamEvent_Usage(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
