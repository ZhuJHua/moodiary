// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_posting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchPosting {

@Id() int get key; List<int> get diaryIsarIds; List<int> get termFreqs;
/// Create a copy of SearchPosting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchPostingCopyWith<SearchPosting> get copyWith => _$SearchPostingCopyWithImpl<SearchPosting>(this as SearchPosting, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchPosting&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.diaryIsarIds, diaryIsarIds)&&const DeepCollectionEquality().equals(other.termFreqs, termFreqs));
}


@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(diaryIsarIds),const DeepCollectionEquality().hash(termFreqs));

@override
String toString() {
  return 'SearchPosting(key: $key, diaryIsarIds: $diaryIsarIds, termFreqs: $termFreqs)';
}


}

/// @nodoc
abstract mixin class $SearchPostingCopyWith<$Res>  {
  factory $SearchPostingCopyWith(SearchPosting value, $Res Function(SearchPosting) _then) = _$SearchPostingCopyWithImpl;
@useResult
$Res call({
@Id() int key, List<int> diaryIsarIds, List<int> termFreqs
});




}
/// @nodoc
class _$SearchPostingCopyWithImpl<$Res>
    implements $SearchPostingCopyWith<$Res> {
  _$SearchPostingCopyWithImpl(this._self, this._then);

  final SearchPosting _self;
  final $Res Function(SearchPosting) _then;

/// Create a copy of SearchPosting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? diaryIsarIds = null,Object? termFreqs = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,diaryIsarIds: null == diaryIsarIds ? _self.diaryIsarIds : diaryIsarIds // ignore: cast_nullable_to_non_nullable
as List<int>,termFreqs: null == termFreqs ? _self.termFreqs : termFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchPosting].
extension SearchPostingPatterns on SearchPosting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchPosting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchPosting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchPosting value)  $default,){
final _that = this;
switch (_that) {
case _SearchPosting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchPosting value)?  $default,){
final _that = this;
switch (_that) {
case _SearchPosting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int key,  List<int> diaryIsarIds,  List<int> termFreqs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchPosting() when $default != null:
return $default(_that.key,_that.diaryIsarIds,_that.termFreqs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int key,  List<int> diaryIsarIds,  List<int> termFreqs)  $default,) {final _that = this;
switch (_that) {
case _SearchPosting():
return $default(_that.key,_that.diaryIsarIds,_that.termFreqs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int key,  List<int> diaryIsarIds,  List<int> termFreqs)?  $default,) {final _that = this;
switch (_that) {
case _SearchPosting() when $default != null:
return $default(_that.key,_that.diaryIsarIds,_that.termFreqs);case _:
  return null;

}
}

}

/// @nodoc


class _SearchPosting extends SearchPosting {
  const _SearchPosting({@Id() required this.key, required final  List<int> diaryIsarIds, required final  List<int> termFreqs}): _diaryIsarIds = diaryIsarIds,_termFreqs = termFreqs,super._();
  

@override@Id() final  int key;
 final  List<int> _diaryIsarIds;
@override List<int> get diaryIsarIds {
  if (_diaryIsarIds is EqualUnmodifiableListView) return _diaryIsarIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diaryIsarIds);
}

 final  List<int> _termFreqs;
@override List<int> get termFreqs {
  if (_termFreqs is EqualUnmodifiableListView) return _termFreqs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_termFreqs);
}


/// Create a copy of SearchPosting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchPostingCopyWith<_SearchPosting> get copyWith => __$SearchPostingCopyWithImpl<_SearchPosting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchPosting&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other._diaryIsarIds, _diaryIsarIds)&&const DeepCollectionEquality().equals(other._termFreqs, _termFreqs));
}


@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(_diaryIsarIds),const DeepCollectionEquality().hash(_termFreqs));

@override
String toString() {
  return 'SearchPosting(key: $key, diaryIsarIds: $diaryIsarIds, termFreqs: $termFreqs)';
}


}

/// @nodoc
abstract mixin class _$SearchPostingCopyWith<$Res> implements $SearchPostingCopyWith<$Res> {
  factory _$SearchPostingCopyWith(_SearchPosting value, $Res Function(_SearchPosting) _then) = __$SearchPostingCopyWithImpl;
@override @useResult
$Res call({
@Id() int key, List<int> diaryIsarIds, List<int> termFreqs
});




}
/// @nodoc
class __$SearchPostingCopyWithImpl<$Res>
    implements _$SearchPostingCopyWith<$Res> {
  __$SearchPostingCopyWithImpl(this._self, this._then);

  final _SearchPosting _self;
  final $Res Function(_SearchPosting) _then;

/// Create a copy of SearchPosting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? diaryIsarIds = null,Object? termFreqs = null,}) {
  return _then(_SearchPosting(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,diaryIsarIds: null == diaryIsarIds ? _self._diaryIsarIds : diaryIsarIds // ignore: cast_nullable_to_non_nullable
as List<int>,termFreqs: null == termFreqs ? _self._termFreqs : termFreqs // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
