// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'link_posting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LinkPosting {

@Id() int get key; List<int> get fromIsarIds;
/// Create a copy of LinkPosting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkPostingCopyWith<LinkPosting> get copyWith => _$LinkPostingCopyWithImpl<LinkPosting>(this as LinkPosting, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkPosting&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.fromIsarIds, fromIsarIds));
}


@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(fromIsarIds));

@override
String toString() {
  return 'LinkPosting(key: $key, fromIsarIds: $fromIsarIds)';
}


}

/// @nodoc
abstract mixin class $LinkPostingCopyWith<$Res>  {
  factory $LinkPostingCopyWith(LinkPosting value, $Res Function(LinkPosting) _then) = _$LinkPostingCopyWithImpl;
@useResult
$Res call({
@Id() int key, List<int> fromIsarIds
});




}
/// @nodoc
class _$LinkPostingCopyWithImpl<$Res>
    implements $LinkPostingCopyWith<$Res> {
  _$LinkPostingCopyWithImpl(this._self, this._then);

  final LinkPosting _self;
  final $Res Function(LinkPosting) _then;

/// Create a copy of LinkPosting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? fromIsarIds = null,}) {
  return _then(LinkPosting(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,fromIsarIds: null == fromIsarIds ? _self.fromIsarIds : fromIsarIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [LinkPosting].
extension LinkPostingPatterns on LinkPosting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkPosting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkPosting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkPosting value)  $default,){
final _that = this;
switch (_that) {
case _LinkPosting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkPosting value)?  $default,){
final _that = this;
switch (_that) {
case _LinkPosting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  int key,  List<int> fromIsarIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkPosting() when $default != null:
return $default(_that.key,_that.fromIsarIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  int key,  List<int> fromIsarIds)  $default,) {final _that = this;
switch (_that) {
case _LinkPosting():
return $default(_that.key,_that.fromIsarIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  int key,  List<int> fromIsarIds)?  $default,) {final _that = this;
switch (_that) {
case _LinkPosting() when $default != null:
return $default(_that.key,_that.fromIsarIds);case _:
  return null;

}
}

}

/// @nodoc


class _LinkPosting extends LinkPosting {
  const _LinkPosting({@Id() required this.key, required  List<int> fromIsarIds}): _fromIsarIds = fromIsarIds,super._();
  

@override@Id() final  int key;
 final  List<int> _fromIsarIds;
@override List<int> get fromIsarIds {
  if (_fromIsarIds is EqualUnmodifiableListView) return _fromIsarIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fromIsarIds);
}


/// Create a copy of LinkPosting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkPostingCopyWith<_LinkPosting> get copyWith => __$LinkPostingCopyWithImpl<_LinkPosting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkPosting&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other._fromIsarIds, _fromIsarIds));
}


@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(_fromIsarIds));

@override
String toString() {
  return 'LinkPosting(key: $key, fromIsarIds: $fromIsarIds)';
}


}

/// @nodoc
abstract mixin class _$LinkPostingCopyWith<$Res> implements $LinkPostingCopyWith<$Res> {
  factory _$LinkPostingCopyWith(_LinkPosting value, $Res Function(_LinkPosting) _then) = __$LinkPostingCopyWithImpl;
@override @useResult
$Res call({
@Id() int key, List<int> fromIsarIds
});




}
/// @nodoc
class __$LinkPostingCopyWithImpl<$Res>
    implements _$LinkPostingCopyWith<$Res> {
  __$LinkPostingCopyWithImpl(this._self, this._then);

  final _LinkPosting _self;
  final $Res Function(_LinkPosting) _then;

/// Create a copy of LinkPosting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? fromIsarIds = null,}) {
  return _then(_LinkPosting(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,fromIsarIds: null == fromIsarIds ? _self._fromIsarIds : fromIsarIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
