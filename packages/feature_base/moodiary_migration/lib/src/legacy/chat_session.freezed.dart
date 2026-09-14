// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatSession {

@Id() String get id; String get title; String get providerId; String get model; DateTime get createdAt; DateTime get updatedAt; String get reasoningEffort; String? get compactedSummary; String? get compactedUpToMessageId; DateTime? get compactedAt; int? get compactedInputTokensAtTrigger; String? get agentPresetId; String? get personaSnapshot; List<String>? get toolsSnapshot;
/// Create a copy of ChatSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSessionCopyWith<ChatSession> get copyWith => _$ChatSessionCopyWithImpl<ChatSession>(this as ChatSession, _$identity);

  /// Serializes this ChatSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChatSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.providerId, _this.providerId) || other.providerId == _this.providerId)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.reasoningEffort, _this.reasoningEffort) || other.reasoningEffort == _this.reasoningEffort)&&(identical(other.compactedSummary, _this.compactedSummary) || other.compactedSummary == _this.compactedSummary)&&(identical(other.compactedUpToMessageId, _this.compactedUpToMessageId) || other.compactedUpToMessageId == _this.compactedUpToMessageId)&&(identical(other.compactedAt, _this.compactedAt) || other.compactedAt == _this.compactedAt)&&(identical(other.compactedInputTokensAtTrigger, _this.compactedInputTokensAtTrigger) || other.compactedInputTokensAtTrigger == _this.compactedInputTokensAtTrigger)&&(identical(other.agentPresetId, _this.agentPresetId) || other.agentPresetId == _this.agentPresetId)&&(identical(other.personaSnapshot, _this.personaSnapshot) || other.personaSnapshot == _this.personaSnapshot)&&const DeepCollectionEquality().equals(other.toolsSnapshot, _this.toolsSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChatSession;
  return Object.hash(runtimeType,_this.id,_this.title,_this.providerId,_this.model,_this.createdAt,_this.updatedAt,_this.reasoningEffort,_this.compactedSummary,_this.compactedUpToMessageId,_this.compactedAt,_this.compactedInputTokensAtTrigger,_this.agentPresetId,_this.personaSnapshot,const DeepCollectionEquality().hash(_this.toolsSnapshot));
}

@override
String toString() {
  final _this = this as ChatSession;
  return 'ChatSession(id: ${_this.id}, title: ${_this.title}, providerId: ${_this.providerId}, model: ${_this.model}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, reasoningEffort: ${_this.reasoningEffort}, compactedSummary: ${_this.compactedSummary}, compactedUpToMessageId: ${_this.compactedUpToMessageId}, compactedAt: ${_this.compactedAt}, compactedInputTokensAtTrigger: ${_this.compactedInputTokensAtTrigger}, agentPresetId: ${_this.agentPresetId}, personaSnapshot: ${_this.personaSnapshot}, toolsSnapshot: ${_this.toolsSnapshot})';
}


}

/// @nodoc
abstract mixin class $ChatSessionCopyWith<$Res>  {
  factory $ChatSessionCopyWith(ChatSession value, $Res Function(ChatSession) _then) = _$ChatSessionCopyWithImpl;
@useResult
$Res call({
@Id() String id, String title, String providerId, String model, DateTime createdAt, DateTime updatedAt, String reasoningEffort, String? compactedSummary, String? compactedUpToMessageId, DateTime? compactedAt, int? compactedInputTokensAtTrigger, String? agentPresetId, String? personaSnapshot, List<String>? toolsSnapshot
});




}
/// @nodoc
class _$ChatSessionCopyWithImpl<$Res>
    implements $ChatSessionCopyWith<$Res> {
  _$ChatSessionCopyWithImpl(this._self, this._then);

  final ChatSession _self;
  final $Res Function(ChatSession) _then;

/// Create a copy of ChatSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? providerId = null,Object? model = null,Object? createdAt = null,Object? updatedAt = null,Object? reasoningEffort = null,Object? compactedSummary = freezed,Object? compactedUpToMessageId = freezed,Object? compactedAt = freezed,Object? compactedInputTokensAtTrigger = freezed,Object? agentPresetId = freezed,Object? personaSnapshot = freezed,Object? toolsSnapshot = freezed,}) {
  return _then(ChatSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reasoningEffort: null == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String,compactedSummary: freezed == compactedSummary ? _self.compactedSummary : compactedSummary // ignore: cast_nullable_to_non_nullable
as String?,compactedUpToMessageId: freezed == compactedUpToMessageId ? _self.compactedUpToMessageId : compactedUpToMessageId // ignore: cast_nullable_to_non_nullable
as String?,compactedAt: freezed == compactedAt ? _self.compactedAt : compactedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,compactedInputTokensAtTrigger: freezed == compactedInputTokensAtTrigger ? _self.compactedInputTokensAtTrigger : compactedInputTokensAtTrigger // ignore: cast_nullable_to_non_nullable
as int?,agentPresetId: freezed == agentPresetId ? _self.agentPresetId : agentPresetId // ignore: cast_nullable_to_non_nullable
as String?,personaSnapshot: freezed == personaSnapshot ? _self.personaSnapshot : personaSnapshot // ignore: cast_nullable_to_non_nullable
as String?,toolsSnapshot: freezed == toolsSnapshot ? _self.toolsSnapshot : toolsSnapshot // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatSession].
extension ChatSessionPatterns on ChatSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatSession value)  $default,){
final _that = this;
switch (_that) {
case _ChatSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatSession value)?  $default,){
final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger,  String? agentPresetId,  String? personaSnapshot,  List<String>? toolsSnapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger,_that.agentPresetId,_that.personaSnapshot,_that.toolsSnapshot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger,  String? agentPresetId,  String? personaSnapshot,  List<String>? toolsSnapshot)  $default,) {final _that = this;
switch (_that) {
case _ChatSession():
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger,_that.agentPresetId,_that.personaSnapshot,_that.toolsSnapshot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger,  String? agentPresetId,  String? personaSnapshot,  List<String>? toolsSnapshot)?  $default,) {final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger,_that.agentPresetId,_that.personaSnapshot,_that.toolsSnapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatSession implements ChatSession {
  const _ChatSession({@Id() required this.id, this.title = '', required this.providerId, required this.model, required this.createdAt, required this.updatedAt, this.reasoningEffort = '', this.compactedSummary, this.compactedUpToMessageId, this.compactedAt, this.compactedInputTokensAtTrigger, this.agentPresetId, this.personaSnapshot,  List<String>? toolsSnapshot}): _toolsSnapshot = toolsSnapshot;
  factory _ChatSession.fromJson(Map<String, dynamic> json) => _$ChatSessionFromJson(json);

@override@Id() final  String id;
@override@JsonKey() final  String title;
@override final  String providerId;
@override final  String model;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  String reasoningEffort;
@override final  String? compactedSummary;
@override final  String? compactedUpToMessageId;
@override final  DateTime? compactedAt;
@override final  int? compactedInputTokensAtTrigger;
@override final  String? agentPresetId;
@override final  String? personaSnapshot;
 final  List<String>? _toolsSnapshot;
@override List<String>? get toolsSnapshot {
  final value = _toolsSnapshot;
  if (value == null) return null;
  if (_toolsSnapshot is EqualUnmodifiableListView) return _toolsSnapshot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ChatSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatSessionCopyWith<_ChatSession> get copyWith => __$ChatSessionCopyWithImpl<_ChatSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatSession&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.model, model) || other.model == model)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.compactedSummary, compactedSummary) || other.compactedSummary == compactedSummary)&&(identical(other.compactedUpToMessageId, compactedUpToMessageId) || other.compactedUpToMessageId == compactedUpToMessageId)&&(identical(other.compactedAt, compactedAt) || other.compactedAt == compactedAt)&&(identical(other.compactedInputTokensAtTrigger, compactedInputTokensAtTrigger) || other.compactedInputTokensAtTrigger == compactedInputTokensAtTrigger)&&(identical(other.agentPresetId, agentPresetId) || other.agentPresetId == agentPresetId)&&(identical(other.personaSnapshot, personaSnapshot) || other.personaSnapshot == personaSnapshot)&&const DeepCollectionEquality().equals(other.toolsSnapshot, _toolsSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,providerId,model,createdAt,updatedAt,reasoningEffort,compactedSummary,compactedUpToMessageId,compactedAt,compactedInputTokensAtTrigger,agentPresetId,personaSnapshot,const DeepCollectionEquality().hash(_toolsSnapshot));
}

@override
String toString() {
    return 'ChatSession(id: $id, title: $title, providerId: $providerId, model: $model, createdAt: $createdAt, updatedAt: $updatedAt, reasoningEffort: $reasoningEffort, compactedSummary: $compactedSummary, compactedUpToMessageId: $compactedUpToMessageId, compactedAt: $compactedAt, compactedInputTokensAtTrigger: $compactedInputTokensAtTrigger, agentPresetId: $agentPresetId, personaSnapshot: $personaSnapshot, toolsSnapshot: $toolsSnapshot)';
}


}

/// @nodoc
abstract mixin class _$ChatSessionCopyWith<$Res> implements $ChatSessionCopyWith<$Res> {
  factory _$ChatSessionCopyWith(_ChatSession value, $Res Function(_ChatSession) _then) = __$ChatSessionCopyWithImpl;
@override @useResult
$Res call({
@Id() String id, String title, String providerId, String model, DateTime createdAt, DateTime updatedAt, String reasoningEffort, String? compactedSummary, String? compactedUpToMessageId, DateTime? compactedAt, int? compactedInputTokensAtTrigger, String? agentPresetId, String? personaSnapshot, List<String>? toolsSnapshot
});




}
/// @nodoc
class __$ChatSessionCopyWithImpl<$Res>
    implements _$ChatSessionCopyWith<$Res> {
  __$ChatSessionCopyWithImpl(this._self, this._then);

  final _ChatSession _self;
  final $Res Function(_ChatSession) _then;

/// Create a copy of ChatSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? providerId = null,Object? model = null,Object? createdAt = null,Object? updatedAt = null,Object? reasoningEffort = null,Object? compactedSummary = freezed,Object? compactedUpToMessageId = freezed,Object? compactedAt = freezed,Object? compactedInputTokensAtTrigger = freezed,Object? agentPresetId = freezed,Object? personaSnapshot = freezed,Object? toolsSnapshot = freezed,}) {
  return _then(_ChatSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reasoningEffort: null == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String,compactedSummary: freezed == compactedSummary ? _self.compactedSummary : compactedSummary // ignore: cast_nullable_to_non_nullable
as String?,compactedUpToMessageId: freezed == compactedUpToMessageId ? _self.compactedUpToMessageId : compactedUpToMessageId // ignore: cast_nullable_to_non_nullable
as String?,compactedAt: freezed == compactedAt ? _self.compactedAt : compactedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,compactedInputTokensAtTrigger: freezed == compactedInputTokensAtTrigger ? _self.compactedInputTokensAtTrigger : compactedInputTokensAtTrigger // ignore: cast_nullable_to_non_nullable
as int?,agentPresetId: freezed == agentPresetId ? _self.agentPresetId : agentPresetId // ignore: cast_nullable_to_non_nullable
as String?,personaSnapshot: freezed == personaSnapshot ? _self.personaSnapshot : personaSnapshot // ignore: cast_nullable_to_non_nullable
as String?,toolsSnapshot: freezed == toolsSnapshot ? _self._toolsSnapshot : toolsSnapshot // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
