// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_search_index.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiarySearchIndex {

@Id() int get id;@Index(hash: true) String get token; int get diaryIsarId; TokenSource get source;
/// Create a copy of DiarySearchIndex
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiarySearchIndexCopyWith<DiarySearchIndex> get copyWith => _$DiarySearchIndexCopyWithImpl<DiarySearchIndex>(this as DiarySearchIndex, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiarySearchIndex&&(identical(other.id, id) || other.id == id)&&(identical(other.token, token) || other.token == token)&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,id,token,diaryIsarId,source);

@override
String toString() {
  return 'DiarySearchIndex(id: $id, token: $token, diaryIsarId: $diaryIsarId, source: $source)';
}


}

/// @nodoc
abstract mixin class $DiarySearchIndexCopyWith<$Res>  {
  factory $DiarySearchIndexCopyWith(DiarySearchIndex value, $Res Function(DiarySearchIndex) _then) = _$DiarySearchIndexCopyWithImpl;
@useResult
$Res call({
@Id() int id,@Index(hash: true) String token, int diaryIsarId, TokenSource source
});




}
/// @nodoc
class _$DiarySearchIndexCopyWithImpl<$Res>
    implements $DiarySearchIndexCopyWith<$Res> {
  _$DiarySearchIndexCopyWithImpl(this._self, this._then);

  final DiarySearchIndex _self;
  final $Res Function(DiarySearchIndex) _then;

/// Create a copy of DiarySearchIndex
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? token = null,Object? diaryIsarId = null,Object? source = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TokenSource,
  ));
}

}


/// Adds pattern-matching-related methods to [DiarySearchIndex].
extension DiarySearchIndexPatterns on DiarySearchIndex {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiarySearchIndex value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiarySearchIndex() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiarySearchIndex value)  $default,){
final _that = this;
switch (_that) {
case _DiarySearchIndex():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiarySearchIndex value)?  $default,){
final _that = this;
switch (_that) {
case _DiarySearchIndex() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int id, @Index(hash: true)  String token,  int diaryIsarId,  TokenSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiarySearchIndex() when $default != null:
return $default(_that.id,_that.token,_that.diaryIsarId,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int id, @Index(hash: true)  String token,  int diaryIsarId,  TokenSource source)  $default,) {final _that = this;
switch (_that) {
case _DiarySearchIndex():
return $default(_that.id,_that.token,_that.diaryIsarId,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int id, @Index(hash: true)  String token,  int diaryIsarId,  TokenSource source)?  $default,) {final _that = this;
switch (_that) {
case _DiarySearchIndex() when $default != null:
return $default(_that.id,_that.token,_that.diaryIsarId,_that.source);case _:
  return null;

}
}

}

/// @nodoc


class _DiarySearchIndex extends DiarySearchIndex {
  const _DiarySearchIndex({@Id() required this.id, @Index(hash: true) required this.token, required this.diaryIsarId, required this.source}): super._();
  

@override@Id() final  int id;
@override@Index(hash: true) final  String token;
@override final  int diaryIsarId;
@override final  TokenSource source;

/// Create a copy of DiarySearchIndex
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiarySearchIndexCopyWith<_DiarySearchIndex> get copyWith => __$DiarySearchIndexCopyWithImpl<_DiarySearchIndex>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiarySearchIndex&&(identical(other.id, id) || other.id == id)&&(identical(other.token, token) || other.token == token)&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,id,token,diaryIsarId,source);

@override
String toString() {
  return 'DiarySearchIndex(id: $id, token: $token, diaryIsarId: $diaryIsarId, source: $source)';
}


}

/// @nodoc
abstract mixin class _$DiarySearchIndexCopyWith<$Res> implements $DiarySearchIndexCopyWith<$Res> {
  factory _$DiarySearchIndexCopyWith(_DiarySearchIndex value, $Res Function(_DiarySearchIndex) _then) = __$DiarySearchIndexCopyWithImpl;
@override @useResult
$Res call({
@Id() int id,@Index(hash: true) String token, int diaryIsarId, TokenSource source
});




}
/// @nodoc
class __$DiarySearchIndexCopyWithImpl<$Res>
    implements _$DiarySearchIndexCopyWith<$Res> {
  __$DiarySearchIndexCopyWithImpl(this._self, this._then);

  final _DiarySearchIndex _self;
  final $Res Function(_DiarySearchIndex) _then;

/// Create a copy of DiarySearchIndex
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? token = null,Object? diaryIsarId = null,Object? source = null,}) {
  return _then(_DiarySearchIndex(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TokenSource,
  ));
}


}

// dart format on
