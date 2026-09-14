// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatMessage {

@Id() String get id;@Index() String get sessionId; String get role; String get content; DateTime get createdAt; String? get reasoning; int? get thinkingMillis; String? get imageName; int? get inputTokens; int? get outputTokens; String? get model; List<AssistantToolCall> get toolCalls;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChatMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.reasoning, _this.reasoning) || other.reasoning == _this.reasoning)&&(identical(other.thinkingMillis, _this.thinkingMillis) || other.thinkingMillis == _this.thinkingMillis)&&(identical(other.imageName, _this.imageName) || other.imageName == _this.imageName)&&(identical(other.inputTokens, _this.inputTokens) || other.inputTokens == _this.inputTokens)&&(identical(other.outputTokens, _this.outputTokens) || other.outputTokens == _this.outputTokens)&&(identical(other.model, _this.model) || other.model == _this.model)&&const DeepCollectionEquality().equals(other.toolCalls, _this.toolCalls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChatMessage;
  return Object.hash(runtimeType,_this.id,_this.sessionId,_this.role,_this.content,_this.createdAt,_this.reasoning,_this.thinkingMillis,_this.imageName,_this.inputTokens,_this.outputTokens,_this.model,const DeepCollectionEquality().hash(_this.toolCalls));
}

@override
String toString() {
  final _this = this as ChatMessage;
  return 'ChatMessage(id: ${_this.id}, sessionId: ${_this.sessionId}, role: ${_this.role}, content: ${_this.content}, createdAt: ${_this.createdAt}, reasoning: ${_this.reasoning}, thinkingMillis: ${_this.thinkingMillis}, imageName: ${_this.imageName}, inputTokens: ${_this.inputTokens}, outputTokens: ${_this.outputTokens}, model: ${_this.model}, toolCalls: ${_this.toolCalls})';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
@Id() String id,@Index() String sessionId, String role, String content, DateTime createdAt, String? reasoning, int? thinkingMillis, String? imageName, int? inputTokens, int? outputTokens, String? model, List<AssistantToolCall> toolCalls
});




}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? role = null,Object? content = null,Object? createdAt = null,Object? reasoning = freezed,Object? thinkingMillis = freezed,Object? imageName = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? model = freezed,Object? toolCalls = null,}) {
  return _then(ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,reasoning: freezed == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as String?,thinkingMillis: freezed == thinkingMillis ? _self.thinkingMillis : thinkingMillis // ignore: cast_nullable_to_non_nullable
as int?,imageName: freezed == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as String?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,toolCalls: null == toolCalls ? _self.toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AssistantToolCall>,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id, @Index()  String sessionId,  String role,  String content,  DateTime createdAt,  String? reasoning,  int? thinkingMillis,  String? imageName,  int? inputTokens,  int? outputTokens,  String? model,  List<AssistantToolCall> toolCalls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.sessionId,_that.role,_that.content,_that.createdAt,_that.reasoning,_that.thinkingMillis,_that.imageName,_that.inputTokens,_that.outputTokens,_that.model,_that.toolCalls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id, @Index()  String sessionId,  String role,  String content,  DateTime createdAt,  String? reasoning,  int? thinkingMillis,  String? imageName,  int? inputTokens,  int? outputTokens,  String? model,  List<AssistantToolCall> toolCalls)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.sessionId,_that.role,_that.content,_that.createdAt,_that.reasoning,_that.thinkingMillis,_that.imageName,_that.inputTokens,_that.outputTokens,_that.model,_that.toolCalls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id, @Index()  String sessionId,  String role,  String content,  DateTime createdAt,  String? reasoning,  int? thinkingMillis,  String? imageName,  int? inputTokens,  int? outputTokens,  String? model,  List<AssistantToolCall> toolCalls)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.sessionId,_that.role,_that.content,_that.createdAt,_that.reasoning,_that.thinkingMillis,_that.imageName,_that.inputTokens,_that.outputTokens,_that.model,_that.toolCalls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessage implements ChatMessage {
  const _ChatMessage({@Id() required this.id, @Index() required this.sessionId, required this.role, required this.content, required this.createdAt, this.reasoning, this.thinkingMillis, this.imageName, this.inputTokens, this.outputTokens, this.model,  List<AssistantToolCall> toolCalls = const <AssistantToolCall>[]}): _toolCalls = toolCalls;
  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

@override@Id() final  String id;
@override@Index() final  String sessionId;
@override final  String role;
@override final  String content;
@override final  DateTime createdAt;
@override final  String? reasoning;
@override final  int? thinkingMillis;
@override final  String? imageName;
@override final  int? inputTokens;
@override final  int? outputTokens;
@override final  String? model;
 final  List<AssistantToolCall> _toolCalls;
@override@JsonKey() List<AssistantToolCall> get toolCalls {
  if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_toolCalls);
}


/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.thinkingMillis, thinkingMillis) || other.thinkingMillis == thinkingMillis)&&(identical(other.imageName, imageName) || other.imageName == imageName)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.toolCalls, _toolCalls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionId,role,content,createdAt,reasoning,thinkingMillis,imageName,inputTokens,outputTokens,model,const DeepCollectionEquality().hash(_toolCalls));
}

@override
String toString() {
    return 'ChatMessage(id: $id, sessionId: $sessionId, role: $role, content: $content, createdAt: $createdAt, reasoning: $reasoning, thinkingMillis: $thinkingMillis, imageName: $imageName, inputTokens: $inputTokens, outputTokens: $outputTokens, model: $model, toolCalls: $toolCalls)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
@Id() String id,@Index() String sessionId, String role, String content, DateTime createdAt, String? reasoning, int? thinkingMillis, String? imageName, int? inputTokens, int? outputTokens, String? model, List<AssistantToolCall> toolCalls
});




}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? role = null,Object? content = null,Object? createdAt = null,Object? reasoning = freezed,Object? thinkingMillis = freezed,Object? imageName = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? model = freezed,Object? toolCalls = null,}) {
  return _then(_ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,reasoning: freezed == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as String?,thinkingMillis: freezed == thinkingMillis ? _self.thinkingMillis : thinkingMillis // ignore: cast_nullable_to_non_nullable
as int?,imageName: freezed == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as String?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,toolCalls: null == toolCalls ? _self._toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AssistantToolCall>,
  ));
}


}

// dart format on
