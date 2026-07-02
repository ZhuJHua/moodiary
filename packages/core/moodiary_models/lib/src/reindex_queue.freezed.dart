// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reindex_queue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReindexQueue {

@Id() int get diaryIsarId;
/// Create a copy of ReindexQueue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReindexQueueCopyWith<ReindexQueue> get copyWith => _$ReindexQueueCopyWithImpl<ReindexQueue>(this as ReindexQueue, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReindexQueue&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId));
}


@override
int get hashCode => Object.hash(runtimeType,diaryIsarId);

@override
String toString() {
  return 'ReindexQueue(diaryIsarId: $diaryIsarId)';
}


}

/// @nodoc
abstract mixin class $ReindexQueueCopyWith<$Res>  {
  factory $ReindexQueueCopyWith(ReindexQueue value, $Res Function(ReindexQueue) _then) = _$ReindexQueueCopyWithImpl;
@useResult
$Res call({
@Id() int diaryIsarId
});




}
/// @nodoc
class _$ReindexQueueCopyWithImpl<$Res>
    implements $ReindexQueueCopyWith<$Res> {
  _$ReindexQueueCopyWithImpl(this._self, this._then);

  final ReindexQueue _self;
  final $Res Function(ReindexQueue) _then;

/// Create a copy of ReindexQueue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diaryIsarId = null,}) {
  return _then(_self.copyWith(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReindexQueue].
extension ReindexQueuePatterns on ReindexQueue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReindexQueue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReindexQueue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReindexQueue value)  $default,){
final _that = this;
switch (_that) {
case _ReindexQueue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReindexQueue value)?  $default,){
final _that = this;
switch (_that) {
case _ReindexQueue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReindexQueue() when $default != null:
return $default(_that.diaryIsarId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId)  $default,) {final _that = this;
switch (_that) {
case _ReindexQueue():
return $default(_that.diaryIsarId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int diaryIsarId)?  $default,) {final _that = this;
switch (_that) {
case _ReindexQueue() when $default != null:
return $default(_that.diaryIsarId);case _:
  return null;

}
}

}

/// @nodoc


class _ReindexQueue extends ReindexQueue {
  const _ReindexQueue({@Id() required this.diaryIsarId}): super._();
  

@override@Id() final  int diaryIsarId;

/// Create a copy of ReindexQueue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReindexQueueCopyWith<_ReindexQueue> get copyWith => __$ReindexQueueCopyWithImpl<_ReindexQueue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReindexQueue&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId));
}


@override
int get hashCode => Object.hash(runtimeType,diaryIsarId);

@override
String toString() {
  return 'ReindexQueue(diaryIsarId: $diaryIsarId)';
}


}

/// @nodoc
abstract mixin class _$ReindexQueueCopyWith<$Res> implements $ReindexQueueCopyWith<$Res> {
  factory _$ReindexQueueCopyWith(_ReindexQueue value, $Res Function(_ReindexQueue) _then) = __$ReindexQueueCopyWithImpl;
@override @useResult
$Res call({
@Id() int diaryIsarId
});




}
/// @nodoc
class __$ReindexQueueCopyWithImpl<$Res>
    implements _$ReindexQueueCopyWith<$Res> {
  __$ReindexQueueCopyWithImpl(this._self, this._then);

  final _ReindexQueue _self;
  final $Res Function(_ReindexQueue) _then;

/// Create a copy of ReindexQueue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diaryIsarId = null,}) {
  return _then(_ReindexQueue(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
