// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_index_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryIndexSnapshot {

@Id() int get diaryIsarId; List<String> get cutTokens; List<String> get cutForSearchTokens; List<String> get linkToIds;
/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryIndexSnapshotCopyWith<DiaryIndexSnapshot> get copyWith => _$DiaryIndexSnapshotCopyWithImpl<DiaryIndexSnapshot>(this as DiaryIndexSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryIndexSnapshot&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId)&&const DeepCollectionEquality().equals(other.cutTokens, cutTokens)&&const DeepCollectionEquality().equals(other.cutForSearchTokens, cutForSearchTokens)&&const DeepCollectionEquality().equals(other.linkToIds, linkToIds));
}


@override
int get hashCode => Object.hash(runtimeType,diaryIsarId,const DeepCollectionEquality().hash(cutTokens),const DeepCollectionEquality().hash(cutForSearchTokens),const DeepCollectionEquality().hash(linkToIds));

@override
String toString() {
  return 'DiaryIndexSnapshot(diaryIsarId: $diaryIsarId, cutTokens: $cutTokens, cutForSearchTokens: $cutForSearchTokens, linkToIds: $linkToIds)';
}


}

/// @nodoc
abstract mixin class $DiaryIndexSnapshotCopyWith<$Res>  {
  factory $DiaryIndexSnapshotCopyWith(DiaryIndexSnapshot value, $Res Function(DiaryIndexSnapshot) _then) = _$DiaryIndexSnapshotCopyWithImpl;
@useResult
$Res call({
@Id() int diaryIsarId, List<String> cutTokens, List<String> cutForSearchTokens, List<String> linkToIds
});




}
/// @nodoc
class _$DiaryIndexSnapshotCopyWithImpl<$Res>
    implements $DiaryIndexSnapshotCopyWith<$Res> {
  _$DiaryIndexSnapshotCopyWithImpl(this._self, this._then);

  final DiaryIndexSnapshot _self;
  final $Res Function(DiaryIndexSnapshot) _then;

/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diaryIsarId = null,Object? cutTokens = null,Object? cutForSearchTokens = null,Object? linkToIds = null,}) {
  return _then(_self.copyWith(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,cutTokens: null == cutTokens ? _self.cutTokens : cutTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutForSearchTokens: null == cutForSearchTokens ? _self.cutForSearchTokens : cutForSearchTokens // ignore: cast_nullable_to_non_nullable
as List<String>,linkToIds: null == linkToIds ? _self.linkToIds : linkToIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryIndexSnapshot].
extension DiaryIndexSnapshotPatterns on DiaryIndexSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaryIndexSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaryIndexSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _DiaryIndexSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaryIndexSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<String> cutForSearchTokens,  List<String> linkToIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutForSearchTokens,_that.linkToIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<String> cutForSearchTokens,  List<String> linkToIds)  $default,) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot():
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutForSearchTokens,_that.linkToIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<String> cutForSearchTokens,  List<String> linkToIds)?  $default,) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutForSearchTokens,_that.linkToIds);case _:
  return null;

}
}

}

/// @nodoc


class _DiaryIndexSnapshot extends DiaryIndexSnapshot {
  const _DiaryIndexSnapshot({@Id() required this.diaryIsarId, required final  List<String> cutTokens, required final  List<String> cutForSearchTokens, required final  List<String> linkToIds}): _cutTokens = cutTokens,_cutForSearchTokens = cutForSearchTokens,_linkToIds = linkToIds,super._();
  

@override@Id() final  int diaryIsarId;
 final  List<String> _cutTokens;
@override List<String> get cutTokens {
  if (_cutTokens is EqualUnmodifiableListView) return _cutTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutTokens);
}

 final  List<String> _cutForSearchTokens;
@override List<String> get cutForSearchTokens {
  if (_cutForSearchTokens is EqualUnmodifiableListView) return _cutForSearchTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutForSearchTokens);
}

 final  List<String> _linkToIds;
@override List<String> get linkToIds {
  if (_linkToIds is EqualUnmodifiableListView) return _linkToIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_linkToIds);
}


/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryIndexSnapshotCopyWith<_DiaryIndexSnapshot> get copyWith => __$DiaryIndexSnapshotCopyWithImpl<_DiaryIndexSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryIndexSnapshot&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId)&&const DeepCollectionEquality().equals(other._cutTokens, _cutTokens)&&const DeepCollectionEquality().equals(other._cutForSearchTokens, _cutForSearchTokens)&&const DeepCollectionEquality().equals(other._linkToIds, _linkToIds));
}


@override
int get hashCode => Object.hash(runtimeType,diaryIsarId,const DeepCollectionEquality().hash(_cutTokens),const DeepCollectionEquality().hash(_cutForSearchTokens),const DeepCollectionEquality().hash(_linkToIds));

@override
String toString() {
  return 'DiaryIndexSnapshot(diaryIsarId: $diaryIsarId, cutTokens: $cutTokens, cutForSearchTokens: $cutForSearchTokens, linkToIds: $linkToIds)';
}


}

/// @nodoc
abstract mixin class _$DiaryIndexSnapshotCopyWith<$Res> implements $DiaryIndexSnapshotCopyWith<$Res> {
  factory _$DiaryIndexSnapshotCopyWith(_DiaryIndexSnapshot value, $Res Function(_DiaryIndexSnapshot) _then) = __$DiaryIndexSnapshotCopyWithImpl;
@override @useResult
$Res call({
@Id() int diaryIsarId, List<String> cutTokens, List<String> cutForSearchTokens, List<String> linkToIds
});




}
/// @nodoc
class __$DiaryIndexSnapshotCopyWithImpl<$Res>
    implements _$DiaryIndexSnapshotCopyWith<$Res> {
  __$DiaryIndexSnapshotCopyWithImpl(this._self, this._then);

  final _DiaryIndexSnapshot _self;
  final $Res Function(_DiaryIndexSnapshot) _then;

/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diaryIsarId = null,Object? cutTokens = null,Object? cutForSearchTokens = null,Object? linkToIds = null,}) {
  return _then(_DiaryIndexSnapshot(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,cutTokens: null == cutTokens ? _self._cutTokens : cutTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutForSearchTokens: null == cutForSearchTokens ? _self._cutForSearchTokens : cutForSearchTokens // ignore: cast_nullable_to_non_nullable
as List<String>,linkToIds: null == linkToIds ? _self._linkToIds : linkToIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
