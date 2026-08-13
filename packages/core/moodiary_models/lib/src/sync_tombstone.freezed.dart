// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_tombstone.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncTombstone {

 String get key; int get timeMs; List<String> get pushedBackends;
/// Create a copy of SyncTombstone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncTombstoneCopyWith<SyncTombstone> get copyWith => _$SyncTombstoneCopyWithImpl<SyncTombstone>(this as SyncTombstone, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncTombstone&&(identical(other.key, key) || other.key == key)&&(identical(other.timeMs, timeMs) || other.timeMs == timeMs)&&const DeepCollectionEquality().equals(other.pushedBackends, pushedBackends));
}


@override
int get hashCode => Object.hash(runtimeType,key,timeMs,const DeepCollectionEquality().hash(pushedBackends));

@override
String toString() {
  return 'SyncTombstone(key: $key, timeMs: $timeMs, pushedBackends: $pushedBackends)';
}


}

/// @nodoc
abstract mixin class $SyncTombstoneCopyWith<$Res>  {
  factory $SyncTombstoneCopyWith(SyncTombstone value, $Res Function(SyncTombstone) _then) = _$SyncTombstoneCopyWithImpl;
@useResult
$Res call({
 String key, int timeMs, List<String> pushedBackends
});




}
/// @nodoc
class _$SyncTombstoneCopyWithImpl<$Res>
    implements $SyncTombstoneCopyWith<$Res> {
  _$SyncTombstoneCopyWithImpl(this._self, this._then);

  final SyncTombstone _self;
  final $Res Function(SyncTombstone) _then;

/// Create a copy of SyncTombstone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? timeMs = null,Object? pushedBackends = null,}) {
  return _then(SyncTombstone(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,pushedBackends: null == pushedBackends ? _self.pushedBackends : pushedBackends // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncTombstone].
extension SyncTombstonePatterns on SyncTombstone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncTombstone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncTombstone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncTombstone value)  $default,){
final _that = this;
switch (_that) {
case _SyncTombstone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncTombstone value)?  $default,){
final _that = this;
switch (_that) {
case _SyncTombstone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  int timeMs,  List<String> pushedBackends)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncTombstone() when $default != null:
return $default(_that.key,_that.timeMs,_that.pushedBackends);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  int timeMs,  List<String> pushedBackends)  $default,) {final _that = this;
switch (_that) {
case _SyncTombstone():
return $default(_that.key,_that.timeMs,_that.pushedBackends);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  int timeMs,  List<String> pushedBackends)?  $default,) {final _that = this;
switch (_that) {
case _SyncTombstone() when $default != null:
return $default(_that.key,_that.timeMs,_that.pushedBackends);case _:
  return null;

}
}

}

/// @nodoc


class _SyncTombstone extends SyncTombstone {
  const _SyncTombstone({required this.key, required this.timeMs, required  List<String> pushedBackends}): _pushedBackends = pushedBackends,super._();
  

@override final  String key;
@override final  int timeMs;
 final  List<String> _pushedBackends;
@override List<String> get pushedBackends {
  if (_pushedBackends is EqualUnmodifiableListView) return _pushedBackends;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pushedBackends);
}


/// Create a copy of SyncTombstone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncTombstoneCopyWith<_SyncTombstone> get copyWith => __$SyncTombstoneCopyWithImpl<_SyncTombstone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncTombstone&&(identical(other.key, key) || other.key == key)&&(identical(other.timeMs, timeMs) || other.timeMs == timeMs)&&const DeepCollectionEquality().equals(other._pushedBackends, _pushedBackends));
}


@override
int get hashCode => Object.hash(runtimeType,key,timeMs,const DeepCollectionEquality().hash(_pushedBackends));

@override
String toString() {
  return 'SyncTombstone(key: $key, timeMs: $timeMs, pushedBackends: $pushedBackends)';
}


}

/// @nodoc
abstract mixin class _$SyncTombstoneCopyWith<$Res> implements $SyncTombstoneCopyWith<$Res> {
  factory _$SyncTombstoneCopyWith(_SyncTombstone value, $Res Function(_SyncTombstone) _then) = __$SyncTombstoneCopyWithImpl;
@override @useResult
$Res call({
 String key, int timeMs, List<String> pushedBackends
});




}
/// @nodoc
class __$SyncTombstoneCopyWithImpl<$Res>
    implements _$SyncTombstoneCopyWith<$Res> {
  __$SyncTombstoneCopyWithImpl(this._self, this._then);

  final _SyncTombstone _self;
  final $Res Function(_SyncTombstone) _then;

/// Create a copy of SyncTombstone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? timeMs = null,Object? pushedBackends = null,}) {
  return _then(_SyncTombstone(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,pushedBackends: null == pushedBackends ? _self._pushedBackends : pushedBackends // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
