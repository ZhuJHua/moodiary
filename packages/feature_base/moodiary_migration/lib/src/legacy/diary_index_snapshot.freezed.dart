// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_index_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryIndexSnapshot {

@Id() int get diaryIsarId; List<String> get cutTokens; List<int> get cutFreqs; List<String> get cutForSearchTokens; List<int> get cutForSearchFreqs; List<String> get titleTokens; List<int> get titleFreqs; List<String> get linkToIds; int get contentChars;
/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryIndexSnapshotCopyWith<DiaryIndexSnapshot> get copyWith => _$DiaryIndexSnapshotCopyWithImpl<DiaryIndexSnapshot>(this as DiaryIndexSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiaryIndexSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryIndexSnapshot&&(identical(other.diaryIsarId, _this.diaryIsarId) || other.diaryIsarId == _this.diaryIsarId)&&const DeepCollectionEquality().equals(other.cutTokens, _this.cutTokens)&&const DeepCollectionEquality().equals(other.cutFreqs, _this.cutFreqs)&&const DeepCollectionEquality().equals(other.cutForSearchTokens, _this.cutForSearchTokens)&&const DeepCollectionEquality().equals(other.cutForSearchFreqs, _this.cutForSearchFreqs)&&const DeepCollectionEquality().equals(other.titleTokens, _this.titleTokens)&&const DeepCollectionEquality().equals(other.titleFreqs, _this.titleFreqs)&&const DeepCollectionEquality().equals(other.linkToIds, _this.linkToIds)&&(identical(other.contentChars, _this.contentChars) || other.contentChars == _this.contentChars));
}


@override
int get hashCode {
  final _this = this as DiaryIndexSnapshot;
  return Object.hash(runtimeType,_this.diaryIsarId,const DeepCollectionEquality().hash(_this.cutTokens),const DeepCollectionEquality().hash(_this.cutFreqs),const DeepCollectionEquality().hash(_this.cutForSearchTokens),const DeepCollectionEquality().hash(_this.cutForSearchFreqs),const DeepCollectionEquality().hash(_this.titleTokens),const DeepCollectionEquality().hash(_this.titleFreqs),const DeepCollectionEquality().hash(_this.linkToIds),_this.contentChars);
}

@override
String toString() {
  final _this = this as DiaryIndexSnapshot;
  return 'DiaryIndexSnapshot(diaryIsarId: ${_this.diaryIsarId}, cutTokens: ${_this.cutTokens}, cutFreqs: ${_this.cutFreqs}, cutForSearchTokens: ${_this.cutForSearchTokens}, cutForSearchFreqs: ${_this.cutForSearchFreqs}, titleTokens: ${_this.titleTokens}, titleFreqs: ${_this.titleFreqs}, linkToIds: ${_this.linkToIds}, contentChars: ${_this.contentChars})';
}


}

/// @nodoc
abstract mixin class $DiaryIndexSnapshotCopyWith<$Res>  {
  factory $DiaryIndexSnapshotCopyWith(DiaryIndexSnapshot value, $Res Function(DiaryIndexSnapshot) _then) = _$DiaryIndexSnapshotCopyWithImpl;
@useResult
$Res call({
@Id() int diaryIsarId, List<String> cutTokens, List<int> cutFreqs, List<String> cutForSearchTokens, List<int> cutForSearchFreqs, List<String> titleTokens, List<int> titleFreqs, List<String> linkToIds, int contentChars
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
@pragma('vm:prefer-inline') @override $Res call({Object? diaryIsarId = null,Object? cutTokens = null,Object? cutFreqs = null,Object? cutForSearchTokens = null,Object? cutForSearchFreqs = null,Object? titleTokens = null,Object? titleFreqs = null,Object? linkToIds = null,Object? contentChars = null,}) {
  return _then(DiaryIndexSnapshot(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,cutTokens: null == cutTokens ? _self.cutTokens : cutTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutFreqs: null == cutFreqs ? _self.cutFreqs : cutFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,cutForSearchTokens: null == cutForSearchTokens ? _self.cutForSearchTokens : cutForSearchTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutForSearchFreqs: null == cutForSearchFreqs ? _self.cutForSearchFreqs : cutForSearchFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,titleTokens: null == titleTokens ? _self.titleTokens : titleTokens // ignore: cast_nullable_to_non_nullable
as List<String>,titleFreqs: null == titleFreqs ? _self.titleFreqs : titleFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,linkToIds: null == linkToIds ? _self.linkToIds : linkToIds // ignore: cast_nullable_to_non_nullable
as List<String>,contentChars: null == contentChars ? _self.contentChars : contentChars // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<int> cutFreqs,  List<String> cutForSearchTokens,  List<int> cutForSearchFreqs,  List<String> titleTokens,  List<int> titleFreqs,  List<String> linkToIds,  int contentChars)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutFreqs,_that.cutForSearchTokens,_that.cutForSearchFreqs,_that.titleTokens,_that.titleFreqs,_that.linkToIds,_that.contentChars);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<int> cutFreqs,  List<String> cutForSearchTokens,  List<int> cutForSearchFreqs,  List<String> titleTokens,  List<int> titleFreqs,  List<String> linkToIds,  int contentChars)  $default,) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot():
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutFreqs,_that.cutForSearchTokens,_that.cutForSearchFreqs,_that.titleTokens,_that.titleFreqs,_that.linkToIds,_that.contentChars);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int diaryIsarId,  List<String> cutTokens,  List<int> cutFreqs,  List<String> cutForSearchTokens,  List<int> cutForSearchFreqs,  List<String> titleTokens,  List<int> titleFreqs,  List<String> linkToIds,  int contentChars)?  $default,) {final _that = this;
switch (_that) {
case _DiaryIndexSnapshot() when $default != null:
return $default(_that.diaryIsarId,_that.cutTokens,_that.cutFreqs,_that.cutForSearchTokens,_that.cutForSearchFreqs,_that.titleTokens,_that.titleFreqs,_that.linkToIds,_that.contentChars);case _:
  return null;

}
}

}

/// @nodoc


class _DiaryIndexSnapshot extends DiaryIndexSnapshot {
  const _DiaryIndexSnapshot({@Id() required this.diaryIsarId, required  List<String> cutTokens, required  List<int> cutFreqs, required  List<String> cutForSearchTokens, required  List<int> cutForSearchFreqs, required  List<String> titleTokens, required  List<int> titleFreqs, required  List<String> linkToIds, required this.contentChars}): _cutTokens = cutTokens,_cutFreqs = cutFreqs,_cutForSearchTokens = cutForSearchTokens,_cutForSearchFreqs = cutForSearchFreqs,_titleTokens = titleTokens,_titleFreqs = titleFreqs,_linkToIds = linkToIds,super._();
  

@override@Id() final  int diaryIsarId;
 final  List<String> _cutTokens;
@override List<String> get cutTokens {
  if (_cutTokens is EqualUnmodifiableListView) return _cutTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutTokens);
}

 final  List<int> _cutFreqs;
@override List<int> get cutFreqs {
  if (_cutFreqs is EqualUnmodifiableListView) return _cutFreqs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutFreqs);
}

 final  List<String> _cutForSearchTokens;
@override List<String> get cutForSearchTokens {
  if (_cutForSearchTokens is EqualUnmodifiableListView) return _cutForSearchTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutForSearchTokens);
}

 final  List<int> _cutForSearchFreqs;
@override List<int> get cutForSearchFreqs {
  if (_cutForSearchFreqs is EqualUnmodifiableListView) return _cutForSearchFreqs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cutForSearchFreqs);
}

 final  List<String> _titleTokens;
@override List<String> get titleTokens {
  if (_titleTokens is EqualUnmodifiableListView) return _titleTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_titleTokens);
}

 final  List<int> _titleFreqs;
@override List<int> get titleFreqs {
  if (_titleFreqs is EqualUnmodifiableListView) return _titleFreqs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_titleFreqs);
}

 final  List<String> _linkToIds;
@override List<String> get linkToIds {
  if (_linkToIds is EqualUnmodifiableListView) return _linkToIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_linkToIds);
}

@override final  int contentChars;

/// Create a copy of DiaryIndexSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaryIndexSnapshotCopyWith<_DiaryIndexSnapshot> get copyWith => __$DiaryIndexSnapshotCopyWithImpl<_DiaryIndexSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaryIndexSnapshot&&(identical(other.diaryIsarId, diaryIsarId) || other.diaryIsarId == diaryIsarId)&&const DeepCollectionEquality().equals(other.cutTokens, _cutTokens)&&const DeepCollectionEquality().equals(other.cutFreqs, _cutFreqs)&&const DeepCollectionEquality().equals(other.cutForSearchTokens, _cutForSearchTokens)&&const DeepCollectionEquality().equals(other.cutForSearchFreqs, _cutForSearchFreqs)&&const DeepCollectionEquality().equals(other.titleTokens, _titleTokens)&&const DeepCollectionEquality().equals(other.titleFreqs, _titleFreqs)&&const DeepCollectionEquality().equals(other.linkToIds, _linkToIds)&&(identical(other.contentChars, contentChars) || other.contentChars == contentChars));
}


@override
int get hashCode {
    return Object.hash(runtimeType,diaryIsarId,const DeepCollectionEquality().hash(_cutTokens),const DeepCollectionEquality().hash(_cutFreqs),const DeepCollectionEquality().hash(_cutForSearchTokens),const DeepCollectionEquality().hash(_cutForSearchFreqs),const DeepCollectionEquality().hash(_titleTokens),const DeepCollectionEquality().hash(_titleFreqs),const DeepCollectionEquality().hash(_linkToIds),contentChars);
}

@override
String toString() {
    return 'DiaryIndexSnapshot(diaryIsarId: $diaryIsarId, cutTokens: $cutTokens, cutFreqs: $cutFreqs, cutForSearchTokens: $cutForSearchTokens, cutForSearchFreqs: $cutForSearchFreqs, titleTokens: $titleTokens, titleFreqs: $titleFreqs, linkToIds: $linkToIds, contentChars: $contentChars)';
}


}

/// @nodoc
abstract mixin class _$DiaryIndexSnapshotCopyWith<$Res> implements $DiaryIndexSnapshotCopyWith<$Res> {
  factory _$DiaryIndexSnapshotCopyWith(_DiaryIndexSnapshot value, $Res Function(_DiaryIndexSnapshot) _then) = __$DiaryIndexSnapshotCopyWithImpl;
@override @useResult
$Res call({
@Id() int diaryIsarId, List<String> cutTokens, List<int> cutFreqs, List<String> cutForSearchTokens, List<int> cutForSearchFreqs, List<String> titleTokens, List<int> titleFreqs, List<String> linkToIds, int contentChars
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
@override @pragma('vm:prefer-inline') $Res call({Object? diaryIsarId = null,Object? cutTokens = null,Object? cutFreqs = null,Object? cutForSearchTokens = null,Object? cutForSearchFreqs = null,Object? titleTokens = null,Object? titleFreqs = null,Object? linkToIds = null,Object? contentChars = null,}) {
  return _then(_DiaryIndexSnapshot(
diaryIsarId: null == diaryIsarId ? _self.diaryIsarId : diaryIsarId // ignore: cast_nullable_to_non_nullable
as int,cutTokens: null == cutTokens ? _self._cutTokens : cutTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutFreqs: null == cutFreqs ? _self._cutFreqs : cutFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,cutForSearchTokens: null == cutForSearchTokens ? _self._cutForSearchTokens : cutForSearchTokens // ignore: cast_nullable_to_non_nullable
as List<String>,cutForSearchFreqs: null == cutForSearchFreqs ? _self._cutForSearchFreqs : cutForSearchFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,titleTokens: null == titleTokens ? _self._titleTokens : titleTokens // ignore: cast_nullable_to_non_nullable
as List<String>,titleFreqs: null == titleFreqs ? _self._titleFreqs : titleFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,linkToIds: null == linkToIds ? _self._linkToIds : linkToIds // ignore: cast_nullable_to_non_nullable
as List<String>,contentChars: null == contentChars ? _self.contentChars : contentChars // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
