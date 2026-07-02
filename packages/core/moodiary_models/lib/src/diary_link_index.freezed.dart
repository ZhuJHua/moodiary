// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_link_index.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryLinkIndex {

@Id() int get id;@Index(hash: true) String get toId; int get fromIsarId;
/// Create a copy of DiaryLinkIndex
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryLinkIndexCopyWith<DiaryLinkIndex> get copyWith => _$DiaryLinkIndexCopyWithImpl<DiaryLinkIndex>(this as DiaryLinkIndex, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryLinkIndex&&(identical(other.id, id) || other.id == id)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.fromIsarId, fromIsarId) || other.fromIsarId == fromIsarId));
}


@override
int get hashCode => Object.hash(runtimeType,id,toId,fromIsarId);

@override
String toString() {
  return 'DiaryLinkIndex(id: $id, toId: $toId, fromIsarId: $fromIsarId)';
}


}

/// @nodoc
abstract mixin class $DiaryLinkIndexCopyWith<$Res>  {
  factory $DiaryLinkIndexCopyWith(DiaryLinkIndex value, $Res Function(DiaryLinkIndex) _then) = _$DiaryLinkIndexCopyWithImpl;
@useResult
$Res call({
@Id() int id,@Index(hash: true) String toId, int fromIsarId
});




}
/// @nodoc
class _$DiaryLinkIndexCopyWithImpl<$Res>
    implements $DiaryLinkIndexCopyWith<$Res> {
  _$DiaryLinkIndexCopyWithImpl(this._self, this._then);

  final DiaryLinkIndex _self;
  final $Res Function(DiaryLinkIndex) _then;

/// Create a copy of DiaryLinkIndex
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? toId = null,Object? fromIsarId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,toId: null == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String,fromIsarId: null == fromIsarId ? _self.fromIsarId : fromIsarId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryLinkIndex].
extension DiaryLinkIndexPatterns on DiaryLinkIndex {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaryLinkIndex value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaryLinkIndex() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaryLinkIndex value)  $default,){
final _that = this;
switch (_that) {
case _DiaryLinkIndex():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaryLinkIndex value)?  $default,){
final _that = this;
switch (_that) {
case _DiaryLinkIndex() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int id, @Index(hash: true)  String toId,  int fromIsarId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryLinkIndex() when $default != null:
return $default(_that.id,_that.toId,_that.fromIsarId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int id, @Index(hash: true)  String toId,  int fromIsarId)  $default,) {final _that = this;
switch (_that) {
case _DiaryLinkIndex():
return $default(_that.id,_that.toId,_that.fromIsarId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int id, @Index(hash: true)  String toId,  int fromIsarId)?  $default,) {final _that = this;
switch (_that) {
case _DiaryLinkIndex() when $default != null:
return $default(_that.id,_that.toId,_that.fromIsarId);case _:
  return null;

}
}

}

/// @nodoc


class _DiaryLinkIndex extends DiaryLinkIndex {
  const _DiaryLinkIndex({@Id() required this.id, @Index(hash: true) required this.toId, required this.fromIsarId}): super._();
  

@override@Id() final  int id;
@override@Index(hash: true) final  String toId;
@override final  int fromIsarId;

/// Create a copy of DiaryLinkIndex
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryLinkIndexCopyWith<_DiaryLinkIndex> get copyWith => __$DiaryLinkIndexCopyWithImpl<_DiaryLinkIndex>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryLinkIndex&&(identical(other.id, id) || other.id == id)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.fromIsarId, fromIsarId) || other.fromIsarId == fromIsarId));
}


@override
int get hashCode => Object.hash(runtimeType,id,toId,fromIsarId);

@override
String toString() {
  return 'DiaryLinkIndex(id: $id, toId: $toId, fromIsarId: $fromIsarId)';
}


}

/// @nodoc
abstract mixin class _$DiaryLinkIndexCopyWith<$Res> implements $DiaryLinkIndexCopyWith<$Res> {
  factory _$DiaryLinkIndexCopyWith(_DiaryLinkIndex value, $Res Function(_DiaryLinkIndex) _then) = __$DiaryLinkIndexCopyWithImpl;
@override @useResult
$Res call({
@Id() int id,@Index(hash: true) String toId, int fromIsarId
});




}
/// @nodoc
class __$DiaryLinkIndexCopyWithImpl<$Res>
    implements _$DiaryLinkIndexCopyWith<$Res> {
  __$DiaryLinkIndexCopyWithImpl(this._self, this._then);

  final _DiaryLinkIndex _self;
  final $Res Function(_DiaryLinkIndex) _then;

/// Create a copy of DiaryLinkIndex
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? toId = null,Object? fromIsarId = null,}) {
  return _then(_DiaryLinkIndex(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,toId: null == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String,fromIsarId: null == fromIsarId ? _self.fromIsarId : fromIsarId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
