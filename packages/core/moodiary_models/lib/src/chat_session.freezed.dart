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

@Id() String get id;/// 空串 = 还没生成过标题，界面显示「新对话」。**不存本地化后的文案**：那会把
/// 生成当时的语种烤进库里，换语言后老会话仍是旧语种。
///
/// 也正是这一位在做幂等：空才生成，生成成功就永远非空。标题在列表里是定位锚点，
/// 自己变了会让人以为点错了会话；失败也不重来——没有手动刷新入口，重来只是白烧。
 String get title;/// 建会话时生效的 [LlmProvider.id]（uuid，不是 [LlmProvider.presetId]）。
///
/// ⚠️ 这两个字段目前**只写不读**：每一轮请求取的都是 `getActiveProvider()`，
/// 所以在设置里换了供应商，已存在的会话下一轮就跟着换模型。要做「会话级模型」
/// 得先让发请求那条路优先读它们。
 String get providerId; String get model; DateTime get createdAt;/// 最后一条消息的时间，列表按此倒序。
 DateTime get updatedAt;/// 本会话的思考强度。空串 = 关；否则是 models.dev `reasoning_options` 里的档位值
/// （`minimal` / `low` / `medium` / `high` / `xhigh` / `max` …）。
/// 新建时取自全局默认 assistantReasoningEffort。
 String get reasoningEffort;/// 上下文压缩：滚动摘要（覆盖至 [compactedUpToMessageId] 为止）；null 表示未压缩，整段历史逐字发送。
 String? get compactedSummary;/// 压缩水位：摘要覆盖到的最后一条消息 id；发送历史时此消息及之前内容改用摘要，Isar 消息永不删除，故可逆。
 String? get compactedUpToMessageId;/// 最近一次压缩的时刻。
 DateTime? get compactedAt;/// 触发压缩时该轮上报的输入 token 数（用于提示 / 调试）。
 int? get compactedInputTokensAtTrigger;
/// Create a copy of ChatSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSessionCopyWith<ChatSession> get copyWith => _$ChatSessionCopyWithImpl<ChatSession>(this as ChatSession, _$identity);

  /// Serializes this ChatSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSession&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.model, model) || other.model == model)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.compactedSummary, compactedSummary) || other.compactedSummary == compactedSummary)&&(identical(other.compactedUpToMessageId, compactedUpToMessageId) || other.compactedUpToMessageId == compactedUpToMessageId)&&(identical(other.compactedAt, compactedAt) || other.compactedAt == compactedAt)&&(identical(other.compactedInputTokensAtTrigger, compactedInputTokensAtTrigger) || other.compactedInputTokensAtTrigger == compactedInputTokensAtTrigger));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,providerId,model,createdAt,updatedAt,reasoningEffort,compactedSummary,compactedUpToMessageId,compactedAt,compactedInputTokensAtTrigger);

@override
String toString() {
  return 'ChatSession(id: $id, title: $title, providerId: $providerId, model: $model, createdAt: $createdAt, updatedAt: $updatedAt, reasoningEffort: $reasoningEffort, compactedSummary: $compactedSummary, compactedUpToMessageId: $compactedUpToMessageId, compactedAt: $compactedAt, compactedInputTokensAtTrigger: $compactedInputTokensAtTrigger)';
}


}

/// @nodoc
abstract mixin class $ChatSessionCopyWith<$Res>  {
  factory $ChatSessionCopyWith(ChatSession value, $Res Function(ChatSession) _then) = _$ChatSessionCopyWithImpl;
@useResult
$Res call({
@Id() String id, String title, String providerId, String model, DateTime createdAt, DateTime updatedAt, String reasoningEffort, String? compactedSummary, String? compactedUpToMessageId, DateTime? compactedAt, int? compactedInputTokensAtTrigger
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? providerId = null,Object? model = null,Object? createdAt = null,Object? updatedAt = null,Object? reasoningEffort = null,Object? compactedSummary = freezed,Object? compactedUpToMessageId = freezed,Object? compactedAt = freezed,Object? compactedInputTokensAtTrigger = freezed,}) {
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
as int?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger)  $default,) {final _that = this;
switch (_that) {
case _ChatSession():
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id,  String title,  String providerId,  String model,  DateTime createdAt,  DateTime updatedAt,  String reasoningEffort,  String? compactedSummary,  String? compactedUpToMessageId,  DateTime? compactedAt,  int? compactedInputTokensAtTrigger)?  $default,) {final _that = this;
switch (_that) {
case _ChatSession() when $default != null:
return $default(_that.id,_that.title,_that.providerId,_that.model,_that.createdAt,_that.updatedAt,_that.reasoningEffort,_that.compactedSummary,_that.compactedUpToMessageId,_that.compactedAt,_that.compactedInputTokensAtTrigger);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatSession implements ChatSession {
  const _ChatSession({@Id() required this.id, this.title = '', required this.providerId, required this.model, required this.createdAt, required this.updatedAt, this.reasoningEffort = '', this.compactedSummary, this.compactedUpToMessageId, this.compactedAt, this.compactedInputTokensAtTrigger});
  factory _ChatSession.fromJson(Map<String, dynamic> json) => _$ChatSessionFromJson(json);

@override@Id() final  String id;
/// 空串 = 还没生成过标题，界面显示「新对话」。**不存本地化后的文案**：那会把
/// 生成当时的语种烤进库里，换语言后老会话仍是旧语种。
///
/// 也正是这一位在做幂等：空才生成，生成成功就永远非空。标题在列表里是定位锚点，
/// 自己变了会让人以为点错了会话；失败也不重来——没有手动刷新入口，重来只是白烧。
@override@JsonKey() final  String title;
/// 建会话时生效的 [LlmProvider.id]（uuid，不是 [LlmProvider.presetId]）。
///
/// ⚠️ 这两个字段目前**只写不读**：每一轮请求取的都是 `getActiveProvider()`，
/// 所以在设置里换了供应商，已存在的会话下一轮就跟着换模型。要做「会话级模型」
/// 得先让发请求那条路优先读它们。
@override final  String providerId;
@override final  String model;
@override final  DateTime createdAt;
/// 最后一条消息的时间，列表按此倒序。
@override final  DateTime updatedAt;
/// 本会话的思考强度。空串 = 关；否则是 models.dev `reasoning_options` 里的档位值
/// （`minimal` / `low` / `medium` / `high` / `xhigh` / `max` …）。
/// 新建时取自全局默认 assistantReasoningEffort。
@override@JsonKey() final  String reasoningEffort;
/// 上下文压缩：滚动摘要（覆盖至 [compactedUpToMessageId] 为止）；null 表示未压缩，整段历史逐字发送。
@override final  String? compactedSummary;
/// 压缩水位：摘要覆盖到的最后一条消息 id；发送历史时此消息及之前内容改用摘要，Isar 消息永不删除，故可逆。
@override final  String? compactedUpToMessageId;
/// 最近一次压缩的时刻。
@override final  DateTime? compactedAt;
/// 触发压缩时该轮上报的输入 token 数（用于提示 / 调试）。
@override final  int? compactedInputTokensAtTrigger;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatSession&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.model, model) || other.model == model)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.compactedSummary, compactedSummary) || other.compactedSummary == compactedSummary)&&(identical(other.compactedUpToMessageId, compactedUpToMessageId) || other.compactedUpToMessageId == compactedUpToMessageId)&&(identical(other.compactedAt, compactedAt) || other.compactedAt == compactedAt)&&(identical(other.compactedInputTokensAtTrigger, compactedInputTokensAtTrigger) || other.compactedInputTokensAtTrigger == compactedInputTokensAtTrigger));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,providerId,model,createdAt,updatedAt,reasoningEffort,compactedSummary,compactedUpToMessageId,compactedAt,compactedInputTokensAtTrigger);

@override
String toString() {
  return 'ChatSession(id: $id, title: $title, providerId: $providerId, model: $model, createdAt: $createdAt, updatedAt: $updatedAt, reasoningEffort: $reasoningEffort, compactedSummary: $compactedSummary, compactedUpToMessageId: $compactedUpToMessageId, compactedAt: $compactedAt, compactedInputTokensAtTrigger: $compactedInputTokensAtTrigger)';
}


}

/// @nodoc
abstract mixin class _$ChatSessionCopyWith<$Res> implements $ChatSessionCopyWith<$Res> {
  factory _$ChatSessionCopyWith(_ChatSession value, $Res Function(_ChatSession) _then) = __$ChatSessionCopyWithImpl;
@override @useResult
$Res call({
@Id() String id, String title, String providerId, String model, DateTime createdAt, DateTime updatedAt, String reasoningEffort, String? compactedSummary, String? compactedUpToMessageId, DateTime? compactedAt, int? compactedInputTokensAtTrigger
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? providerId = null,Object? model = null,Object? createdAt = null,Object? updatedAt = null,Object? reasoningEffort = null,Object? compactedSummary = freezed,Object? compactedUpToMessageId = freezed,Object? compactedAt = freezed,Object? compactedInputTokensAtTrigger = freezed,}) {
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
as int?,
  ));
}


}

// dart format on
