// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiarySearchState {

 List<Diary> get results; List<String> get queryList; bool get isSearching; Duration? get elapsed; String get query; String? get categoryId; DateRangePreset get datePreset; DateTime? get customStart; DateTime? get customEnd; SearchSort get sort;
/// Create a copy of DiarySearchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiarySearchStateCopyWith<DiarySearchState> get copyWith => _$DiarySearchStateCopyWithImpl<DiarySearchState>(this as DiarySearchState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiarySearchState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiarySearchState&&const DeepCollectionEquality().equals(other.results, _this.results)&&const DeepCollectionEquality().equals(other.queryList, _this.queryList)&&(identical(other.isSearching, _this.isSearching) || other.isSearching == _this.isSearching)&&(identical(other.elapsed, _this.elapsed) || other.elapsed == _this.elapsed)&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.datePreset, _this.datePreset) || other.datePreset == _this.datePreset)&&(identical(other.customStart, _this.customStart) || other.customStart == _this.customStart)&&(identical(other.customEnd, _this.customEnd) || other.customEnd == _this.customEnd)&&(identical(other.sort, _this.sort) || other.sort == _this.sort));
}


@override
int get hashCode {
  final _this = this as DiarySearchState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.results),const DeepCollectionEquality().hash(_this.queryList),_this.isSearching,_this.elapsed,_this.query,_this.categoryId,_this.datePreset,_this.customStart,_this.customEnd,_this.sort);
}

@override
String toString() {
  final _this = this as DiarySearchState;
  return 'DiarySearchState(results: ${_this.results}, queryList: ${_this.queryList}, isSearching: ${_this.isSearching}, elapsed: ${_this.elapsed}, query: ${_this.query}, categoryId: ${_this.categoryId}, datePreset: ${_this.datePreset}, customStart: ${_this.customStart}, customEnd: ${_this.customEnd}, sort: ${_this.sort})';
}


}

/// @nodoc
abstract mixin class $DiarySearchStateCopyWith<$Res>  {
  factory $DiarySearchStateCopyWith(DiarySearchState value, $Res Function(DiarySearchState) _then) = _$DiarySearchStateCopyWithImpl;
@useResult
$Res call({
 List<Diary> results, List<String> queryList, bool isSearching, Duration? elapsed, String query, String? categoryId, DateRangePreset datePreset, DateTime? customStart, DateTime? customEnd, SearchSort sort
});




}
/// @nodoc
class _$DiarySearchStateCopyWithImpl<$Res>
    implements $DiarySearchStateCopyWith<$Res> {
  _$DiarySearchStateCopyWithImpl(this._self, this._then);

  final DiarySearchState _self;
  final $Res Function(DiarySearchState) _then;

/// Create a copy of DiarySearchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? results = null,Object? queryList = null,Object? isSearching = null,Object? elapsed = freezed,Object? query = null,Object? categoryId = freezed,Object? datePreset = null,Object? customStart = freezed,Object? customEnd = freezed,Object? sort = null,}) {
  return _then(DiarySearchState(
results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<Diary>,queryList: null == queryList ? _self.queryList : queryList // ignore: cast_nullable_to_non_nullable
as List<String>,isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,elapsed: freezed == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as Duration?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,datePreset: null == datePreset ? _self.datePreset : datePreset // ignore: cast_nullable_to_non_nullable
as DateRangePreset,customStart: freezed == customStart ? _self.customStart : customStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customEnd: freezed == customEnd ? _self.customEnd : customEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as SearchSort,
  ));
}

}


/// Adds pattern-matching-related methods to [DiarySearchState].
extension DiarySearchStatePatterns on DiarySearchState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiarySearchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiarySearchState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiarySearchState value)  $default,){
final _that = this;
switch (_that) {
case _DiarySearchState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiarySearchState value)?  $default,){
final _that = this;
switch (_that) {
case _DiarySearchState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Diary> results,  List<String> queryList,  bool isSearching,  Duration? elapsed,  String query,  String? categoryId,  DateRangePreset datePreset,  DateTime? customStart,  DateTime? customEnd,  SearchSort sort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiarySearchState() when $default != null:
return $default(_that.results,_that.queryList,_that.isSearching,_that.elapsed,_that.query,_that.categoryId,_that.datePreset,_that.customStart,_that.customEnd,_that.sort);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Diary> results,  List<String> queryList,  bool isSearching,  Duration? elapsed,  String query,  String? categoryId,  DateRangePreset datePreset,  DateTime? customStart,  DateTime? customEnd,  SearchSort sort)  $default,) {final _that = this;
switch (_that) {
case _DiarySearchState():
return $default(_that.results,_that.queryList,_that.isSearching,_that.elapsed,_that.query,_that.categoryId,_that.datePreset,_that.customStart,_that.customEnd,_that.sort);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Diary> results,  List<String> queryList,  bool isSearching,  Duration? elapsed,  String query,  String? categoryId,  DateRangePreset datePreset,  DateTime? customStart,  DateTime? customEnd,  SearchSort sort)?  $default,) {final _that = this;
switch (_that) {
case _DiarySearchState() when $default != null:
return $default(_that.results,_that.queryList,_that.isSearching,_that.elapsed,_that.query,_that.categoryId,_that.datePreset,_that.customStart,_that.customEnd,_that.sort);case _:
  return null;

}
}

}

/// @nodoc


class _DiarySearchState extends DiarySearchState {
  const _DiarySearchState({ List<Diary> results = const [],  List<String> queryList = const [], this.isSearching = false, this.elapsed, this.query = '', this.categoryId, this.datePreset = DateRangePreset.all, this.customStart, this.customEnd, this.sort = SearchSort.relevance}): _results = results,_queryList = queryList,super._();
  

 final  List<Diary> _results;
@override@JsonKey() List<Diary> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}

 final  List<String> _queryList;
@override@JsonKey() List<String> get queryList {
  if (_queryList is EqualUnmodifiableListView) return _queryList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_queryList);
}

@override@JsonKey() final  bool isSearching;
@override final  Duration? elapsed;
@override@JsonKey() final  String query;
@override final  String? categoryId;
@override@JsonKey() final  DateRangePreset datePreset;
@override final  DateTime? customStart;
@override final  DateTime? customEnd;
@override@JsonKey() final  SearchSort sort;

/// Create a copy of DiarySearchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiarySearchStateCopyWith<_DiarySearchState> get copyWith => __$DiarySearchStateCopyWithImpl<_DiarySearchState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiarySearchState&&const DeepCollectionEquality().equals(other.results, _results)&&const DeepCollectionEquality().equals(other.queryList, _queryList)&&(identical(other.isSearching, isSearching) || other.isSearching == isSearching)&&(identical(other.elapsed, elapsed) || other.elapsed == elapsed)&&(identical(other.query, query) || other.query == query)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.datePreset, datePreset) || other.datePreset == datePreset)&&(identical(other.customStart, customStart) || other.customStart == customStart)&&(identical(other.customEnd, customEnd) || other.customEnd == customEnd)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_results),const DeepCollectionEquality().hash(_queryList),isSearching,elapsed,query,categoryId,datePreset,customStart,customEnd,sort);
}

@override
String toString() {
    return 'DiarySearchState(results: $results, queryList: $queryList, isSearching: $isSearching, elapsed: $elapsed, query: $query, categoryId: $categoryId, datePreset: $datePreset, customStart: $customStart, customEnd: $customEnd, sort: $sort)';
}


}

/// @nodoc
abstract mixin class _$DiarySearchStateCopyWith<$Res> implements $DiarySearchStateCopyWith<$Res> {
  factory _$DiarySearchStateCopyWith(_DiarySearchState value, $Res Function(_DiarySearchState) _then) = __$DiarySearchStateCopyWithImpl;
@override @useResult
$Res call({
 List<Diary> results, List<String> queryList, bool isSearching, Duration? elapsed, String query, String? categoryId, DateRangePreset datePreset, DateTime? customStart, DateTime? customEnd, SearchSort sort
});




}
/// @nodoc
class __$DiarySearchStateCopyWithImpl<$Res>
    implements _$DiarySearchStateCopyWith<$Res> {
  __$DiarySearchStateCopyWithImpl(this._self, this._then);

  final _DiarySearchState _self;
  final $Res Function(_DiarySearchState) _then;

/// Create a copy of DiarySearchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? results = null,Object? queryList = null,Object? isSearching = null,Object? elapsed = freezed,Object? query = null,Object? categoryId = freezed,Object? datePreset = null,Object? customStart = freezed,Object? customEnd = freezed,Object? sort = null,}) {
  return _then(_DiarySearchState(
results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<Diary>,queryList: null == queryList ? _self._queryList : queryList // ignore: cast_nullable_to_non_nullable
as List<String>,isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,elapsed: freezed == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as Duration?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,datePreset: null == datePreset ? _self.datePreset : datePreset // ignore: cast_nullable_to_non_nullable
as DateRangePreset,customStart: freezed == customStart ? _self.customStart : customStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customEnd: freezed == customEnd ? _self.customEnd : customEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as SearchSort,
  ));
}


}

// dart format on
