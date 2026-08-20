// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchStats {

@Id() int get id; int get docCount; int get contentDocCount; int get totalContentChars;
/// Create a copy of SearchStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchStatsCopyWith<SearchStats> get copyWith => _$SearchStatsCopyWithImpl<SearchStats>(this as SearchStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchStats&&(identical(other.id, id) || other.id == id)&&(identical(other.docCount, docCount) || other.docCount == docCount)&&(identical(other.contentDocCount, contentDocCount) || other.contentDocCount == contentDocCount)&&(identical(other.totalContentChars, totalContentChars) || other.totalContentChars == totalContentChars));
}


@override
int get hashCode => Object.hash(runtimeType,id,docCount,contentDocCount,totalContentChars);

@override
String toString() {
  return 'SearchStats(id: $id, docCount: $docCount, contentDocCount: $contentDocCount, totalContentChars: $totalContentChars)';
}


}

/// @nodoc
abstract mixin class $SearchStatsCopyWith<$Res>  {
  factory $SearchStatsCopyWith(SearchStats value, $Res Function(SearchStats) _then) = _$SearchStatsCopyWithImpl;
@useResult
$Res call({
@Id() int id, int docCount, int contentDocCount, int totalContentChars
});




}
/// @nodoc
class _$SearchStatsCopyWithImpl<$Res>
    implements $SearchStatsCopyWith<$Res> {
  _$SearchStatsCopyWithImpl(this._self, this._then);

  final SearchStats _self;
  final $Res Function(SearchStats) _then;

/// Create a copy of SearchStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? docCount = null,Object? contentDocCount = null,Object? totalContentChars = null,}) {
  return _then(SearchStats(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,docCount: null == docCount ? _self.docCount : docCount // ignore: cast_nullable_to_non_nullable
as int,contentDocCount: null == contentDocCount ? _self.contentDocCount : contentDocCount // ignore: cast_nullable_to_non_nullable
as int,totalContentChars: null == totalContentChars ? _self.totalContentChars : totalContentChars // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchStats].
extension SearchStatsPatterns on SearchStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchStats value)  $default,){
final _that = this;
switch (_that) {
case _SearchStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchStats value)?  $default,){
final _that = this;
switch (_that) {
case _SearchStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int id,  int docCount,  int contentDocCount,  int totalContentChars)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchStats() when $default != null:
return $default(_that.id,_that.docCount,_that.contentDocCount,_that.totalContentChars);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int id,  int docCount,  int contentDocCount,  int totalContentChars)  $default,) {final _that = this;
switch (_that) {
case _SearchStats():
return $default(_that.id,_that.docCount,_that.contentDocCount,_that.totalContentChars);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int id,  int docCount,  int contentDocCount,  int totalContentChars)?  $default,) {final _that = this;
switch (_that) {
case _SearchStats() when $default != null:
return $default(_that.id,_that.docCount,_that.contentDocCount,_that.totalContentChars);case _:
  return null;

}
}

}

/// @nodoc


class _SearchStats extends SearchStats {
  const _SearchStats({@Id() required this.id, required this.docCount, required this.contentDocCount, required this.totalContentChars}): super._();
  

@override@Id() final  int id;
@override final  int docCount;
@override final  int contentDocCount;
@override final  int totalContentChars;

/// Create a copy of SearchStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchStatsCopyWith<_SearchStats> get copyWith => __$SearchStatsCopyWithImpl<_SearchStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchStats&&(identical(other.id, id) || other.id == id)&&(identical(other.docCount, docCount) || other.docCount == docCount)&&(identical(other.contentDocCount, contentDocCount) || other.contentDocCount == contentDocCount)&&(identical(other.totalContentChars, totalContentChars) || other.totalContentChars == totalContentChars));
}


@override
int get hashCode => Object.hash(runtimeType,id,docCount,contentDocCount,totalContentChars);

@override
String toString() {
  return 'SearchStats(id: $id, docCount: $docCount, contentDocCount: $contentDocCount, totalContentChars: $totalContentChars)';
}


}

/// @nodoc
abstract mixin class _$SearchStatsCopyWith<$Res> implements $SearchStatsCopyWith<$Res> {
  factory _$SearchStatsCopyWith(_SearchStats value, $Res Function(_SearchStats) _then) = __$SearchStatsCopyWithImpl;
@override @useResult
$Res call({
@Id() int id, int docCount, int contentDocCount, int totalContentChars
});




}
/// @nodoc
class __$SearchStatsCopyWithImpl<$Res>
    implements _$SearchStatsCopyWith<$Res> {
  __$SearchStatsCopyWithImpl(this._self, this._then);

  final _SearchStats _self;
  final $Res Function(_SearchStats) _then;

/// Create a copy of SearchStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? docCount = null,Object? contentDocCount = null,Object? totalContentChars = null,}) {
  return _then(_SearchStats(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,docCount: null == docCount ? _self.docCount : docCount // ignore: cast_nullable_to_non_nullable
as int,contentDocCount: null == contentDocCount ? _self.contentDocCount : contentDocCount // ignore: cast_nullable_to_non_nullable
as int,totalContentChars: null == totalContentChars ? _self.totalContentChars : totalContentChars // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
