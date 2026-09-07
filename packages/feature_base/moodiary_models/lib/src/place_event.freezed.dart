// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'place_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaceEvent {

 bool get fromSync;
/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceEventCopyWith<PlaceEvent> get copyWith => _$PlaceEventCopyWithImpl<PlaceEvent>(this as PlaceEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaceEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaceEvent&&(identical(other.fromSync, _this.fromSync) || other.fromSync == _this.fromSync));
}


@override
int get hashCode {
  final _this = this as PlaceEvent;
  return Object.hash(runtimeType,_this.fromSync);
}

@override
String toString() {
  final _this = this as PlaceEvent;
  return 'PlaceEvent(fromSync: ${_this.fromSync})';
}


}

/// @nodoc
abstract mixin class $PlaceEventCopyWith<$Res>  {
  factory $PlaceEventCopyWith(PlaceEvent value, $Res Function(PlaceEvent) _then) = _$PlaceEventCopyWithImpl;
@useResult
$Res call({
 bool fromSync
});




}
/// @nodoc
class _$PlaceEventCopyWithImpl<$Res>
    implements $PlaceEventCopyWith<$Res> {
  _$PlaceEventCopyWithImpl(this._self, this._then);

  final PlaceEvent _self;
  final $Res Function(PlaceEvent) _then;

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromSync = null,}) {
  return _then(_self.copyWith(
fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaceEvent].
extension PlaceEventPatterns on PlaceEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlaceUpserted value)?  upserted,TResult Function( PlaceDeleted value)?  deleted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlaceUpserted() when upserted != null:
return upserted(_that);case PlaceDeleted() when deleted != null:
return deleted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlaceUpserted value)  upserted,required TResult Function( PlaceDeleted value)  deleted,}){
final _that = this;
switch (_that) {
case PlaceUpserted():
return upserted(_that);case PlaceDeleted():
return deleted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlaceUpserted value)?  upserted,TResult? Function( PlaceDeleted value)?  deleted,}){
final _that = this;
switch (_that) {
case PlaceUpserted() when upserted != null:
return upserted(_that);case PlaceDeleted() when deleted != null:
return deleted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Place place,  bool fromSync)?  upserted,TResult Function( String id,  bool fromSync)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlaceUpserted() when upserted != null:
return upserted(_that.place,_that.fromSync);case PlaceDeleted() when deleted != null:
return deleted(_that.id,_that.fromSync);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Place place,  bool fromSync)  upserted,required TResult Function( String id,  bool fromSync)  deleted,}) {final _that = this;
switch (_that) {
case PlaceUpserted():
return upserted(_that.place,_that.fromSync);case PlaceDeleted():
return deleted(_that.id,_that.fromSync);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Place place,  bool fromSync)?  upserted,TResult? Function( String id,  bool fromSync)?  deleted,}) {final _that = this;
switch (_that) {
case PlaceUpserted() when upserted != null:
return upserted(_that.place,_that.fromSync);case PlaceDeleted() when deleted != null:
return deleted(_that.id,_that.fromSync);case _:
  return null;

}
}

}

/// @nodoc


class PlaceUpserted implements PlaceEvent {
  const PlaceUpserted(this.place, {this.fromSync = false});
  

 final  Place place;
@override@JsonKey() final  bool fromSync;

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceUpsertedCopyWith<PlaceUpserted> get copyWith => _$PlaceUpsertedCopyWithImpl<PlaceUpserted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaceUpserted&&(identical(other.place, place) || other.place == place)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,place,fromSync);
}

@override
String toString() {
    return 'PlaceEvent.upserted(place: $place, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $PlaceUpsertedCopyWith<$Res> implements $PlaceEventCopyWith<$Res> {
  factory $PlaceUpsertedCopyWith(PlaceUpserted value, $Res Function(PlaceUpserted) _then) = _$PlaceUpsertedCopyWithImpl;
@override @useResult
$Res call({
 Place place, bool fromSync
});


$PlaceCopyWith<$Res> get place;

}
/// @nodoc
class _$PlaceUpsertedCopyWithImpl<$Res>
    implements $PlaceUpsertedCopyWith<$Res> {
  _$PlaceUpsertedCopyWithImpl(this._self, this._then);

  final PlaceUpserted _self;
  final $Res Function(PlaceUpserted) _then;

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? place = null,Object? fromSync = null,}) {
  return _then(PlaceUpserted(
null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as Place,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get place {
  
  return $PlaceCopyWith<$Res>(_self.place, (value) {
    return _then(_self.copyWith(place: value));
  });
}
}

/// @nodoc


class PlaceDeleted implements PlaceEvent {
  const PlaceDeleted(this.id, {this.fromSync = false});
  

 final  String id;
@override@JsonKey() final  bool fromSync;

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceDeletedCopyWith<PlaceDeleted> get copyWith => _$PlaceDeletedCopyWithImpl<PlaceDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaceDeleted&&(identical(other.id, id) || other.id == id)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,fromSync);
}

@override
String toString() {
    return 'PlaceEvent.deleted(id: $id, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $PlaceDeletedCopyWith<$Res> implements $PlaceEventCopyWith<$Res> {
  factory $PlaceDeletedCopyWith(PlaceDeleted value, $Res Function(PlaceDeleted) _then) = _$PlaceDeletedCopyWithImpl;
@override @useResult
$Res call({
 String id, bool fromSync
});




}
/// @nodoc
class _$PlaceDeletedCopyWithImpl<$Res>
    implements $PlaceDeletedCopyWith<$Res> {
  _$PlaceDeletedCopyWithImpl(this._self, this._then);

  final PlaceDeleted _self;
  final $Res Function(PlaceDeleted) _then;

/// Create a copy of PlaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromSync = null,}) {
  return _then(PlaceDeleted(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
