// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryEvent {

 bool get fromSync;
/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryEventCopyWith<DiaryEvent> get copyWith => _$DiaryEventCopyWithImpl<DiaryEvent>(this as DiaryEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiaryEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryEvent&&(identical(other.fromSync, _this.fromSync) || other.fromSync == _this.fromSync));
}


@override
int get hashCode {
  final _this = this as DiaryEvent;
  return Object.hash(runtimeType,_this.fromSync);
}

@override
String toString() {
  final _this = this as DiaryEvent;
  return 'DiaryEvent(fromSync: ${_this.fromSync})';
}


}

/// @nodoc
abstract mixin class $DiaryEventCopyWith<$Res>  {
  factory $DiaryEventCopyWith(DiaryEvent value, $Res Function(DiaryEvent) _then) = _$DiaryEventCopyWithImpl;
@useResult
$Res call({
 bool fromSync
});




}
/// @nodoc
class _$DiaryEventCopyWithImpl<$Res>
    implements $DiaryEventCopyWith<$Res> {
  _$DiaryEventCopyWithImpl(this._self, this._then);

  final DiaryEvent _self;
  final $Res Function(DiaryEvent) _then;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromSync = null,}) {
  return _then(_self.copyWith(
fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaryEvent].
extension DiaryEventPatterns on DiaryEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DiaryCreated value)?  created,TResult Function( DiaryUpdated value)?  updated,TResult Function( DiaryDeleted value)?  deleted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that);case DiaryUpdated() when updated != null:
return updated(_that);case DiaryDeleted() when deleted != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DiaryCreated value)  created,required TResult Function( DiaryUpdated value)  updated,required TResult Function( DiaryDeleted value)  deleted,}){
final _that = this;
switch (_that) {
case DiaryCreated():
return created(_that);case DiaryUpdated():
return updated(_that);case DiaryDeleted():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DiaryCreated value)?  created,TResult? Function( DiaryUpdated value)?  updated,TResult? Function( DiaryDeleted value)?  deleted,}){
final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that);case DiaryUpdated() when updated != null:
return updated(_that);case DiaryDeleted() when deleted != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Diary diary,  bool fromSync)?  created,TResult Function( Diary diary,  bool fromSync)?  updated,TResult Function( String id,  bool fromSync)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that.diary,_that.fromSync);case DiaryUpdated() when updated != null:
return updated(_that.diary,_that.fromSync);case DiaryDeleted() when deleted != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Diary diary,  bool fromSync)  created,required TResult Function( Diary diary,  bool fromSync)  updated,required TResult Function( String id,  bool fromSync)  deleted,}) {final _that = this;
switch (_that) {
case DiaryCreated():
return created(_that.diary,_that.fromSync);case DiaryUpdated():
return updated(_that.diary,_that.fromSync);case DiaryDeleted():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Diary diary,  bool fromSync)?  created,TResult? Function( Diary diary,  bool fromSync)?  updated,TResult? Function( String id,  bool fromSync)?  deleted,}) {final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that.diary,_that.fromSync);case DiaryUpdated() when updated != null:
return updated(_that.diary,_that.fromSync);case DiaryDeleted() when deleted != null:
return deleted(_that.id,_that.fromSync);case _:
  return null;

}
}

}

/// @nodoc


class DiaryCreated implements DiaryEvent {
  const DiaryCreated(this.diary, {this.fromSync = false});
  

 final  Diary diary;
@override@JsonKey() final  bool fromSync;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryCreatedCopyWith<DiaryCreated> get copyWith => _$DiaryCreatedCopyWithImpl<DiaryCreated>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryCreated&&(identical(other.diary, diary) || other.diary == diary)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,diary,fromSync);
}

@override
String toString() {
    return 'DiaryEvent.created(diary: $diary, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $DiaryCreatedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryCreatedCopyWith(DiaryCreated value, $Res Function(DiaryCreated) _then) = _$DiaryCreatedCopyWithImpl;
@override @useResult
$Res call({
 Diary diary, bool fromSync
});


$DiaryCopyWith<$Res> get diary;

}
/// @nodoc
class _$DiaryCreatedCopyWithImpl<$Res>
    implements $DiaryCreatedCopyWith<$Res> {
  _$DiaryCreatedCopyWithImpl(this._self, this._then);

  final DiaryCreated _self;
  final $Res Function(DiaryCreated) _then;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diary = null,Object? fromSync = null,}) {
  return _then(DiaryCreated(
null == diary ? _self.diary : diary // ignore: cast_nullable_to_non_nullable
as Diary,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryCopyWith<$Res> get diary {
  
  return $DiaryCopyWith<$Res>(_self.diary, (value) {
    return _then(_self.copyWith(diary: value));
  });
}
}

/// @nodoc


class DiaryUpdated implements DiaryEvent {
  const DiaryUpdated(this.diary, {this.fromSync = false});
  

 final  Diary diary;
@override@JsonKey() final  bool fromSync;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryUpdatedCopyWith<DiaryUpdated> get copyWith => _$DiaryUpdatedCopyWithImpl<DiaryUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryUpdated&&(identical(other.diary, diary) || other.diary == diary)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,diary,fromSync);
}

@override
String toString() {
    return 'DiaryEvent.updated(diary: $diary, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $DiaryUpdatedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryUpdatedCopyWith(DiaryUpdated value, $Res Function(DiaryUpdated) _then) = _$DiaryUpdatedCopyWithImpl;
@override @useResult
$Res call({
 Diary diary, bool fromSync
});


$DiaryCopyWith<$Res> get diary;

}
/// @nodoc
class _$DiaryUpdatedCopyWithImpl<$Res>
    implements $DiaryUpdatedCopyWith<$Res> {
  _$DiaryUpdatedCopyWithImpl(this._self, this._then);

  final DiaryUpdated _self;
  final $Res Function(DiaryUpdated) _then;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diary = null,Object? fromSync = null,}) {
  return _then(DiaryUpdated(
null == diary ? _self.diary : diary // ignore: cast_nullable_to_non_nullable
as Diary,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiaryCopyWith<$Res> get diary {
  
  return $DiaryCopyWith<$Res>(_self.diary, (value) {
    return _then(_self.copyWith(diary: value));
  });
}
}

/// @nodoc


class DiaryDeleted implements DiaryEvent {
  const DiaryDeleted(this.id, {this.fromSync = false});
  

 final  String id;
@override@JsonKey() final  bool fromSync;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryDeletedCopyWith<DiaryDeleted> get copyWith => _$DiaryDeletedCopyWithImpl<DiaryDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryDeleted&&(identical(other.id, id) || other.id == id)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,fromSync);
}

@override
String toString() {
    return 'DiaryEvent.deleted(id: $id, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $DiaryDeletedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryDeletedCopyWith(DiaryDeleted value, $Res Function(DiaryDeleted) _then) = _$DiaryDeletedCopyWithImpl;
@override @useResult
$Res call({
 String id, bool fromSync
});




}
/// @nodoc
class _$DiaryDeletedCopyWithImpl<$Res>
    implements $DiaryDeletedCopyWith<$Res> {
  _$DiaryDeletedCopyWithImpl(this._self, this._then);

  final DiaryDeleted _self;
  final $Res Function(DiaryDeleted) _then;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromSync = null,}) {
  return _then(DiaryDeleted(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
