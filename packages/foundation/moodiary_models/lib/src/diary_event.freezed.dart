// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiaryEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiaryEvent()';
}


}

/// @nodoc
class $DiaryEventCopyWith<$Res>  {
$DiaryEventCopyWith(DiaryEvent _, $Res Function(DiaryEvent) __);
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Diary diary)?  created,TResult Function( Diary diary)?  updated,TResult Function( int isarId)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that.diary);case DiaryUpdated() when updated != null:
return updated(_that.diary);case DiaryDeleted() when deleted != null:
return deleted(_that.isarId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Diary diary)  created,required TResult Function( Diary diary)  updated,required TResult Function( int isarId)  deleted,}) {final _that = this;
switch (_that) {
case DiaryCreated():
return created(_that.diary);case DiaryUpdated():
return updated(_that.diary);case DiaryDeleted():
return deleted(_that.isarId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Diary diary)?  created,TResult? Function( Diary diary)?  updated,TResult? Function( int isarId)?  deleted,}) {final _that = this;
switch (_that) {
case DiaryCreated() when created != null:
return created(_that.diary);case DiaryUpdated() when updated != null:
return updated(_that.diary);case DiaryDeleted() when deleted != null:
return deleted(_that.isarId);case _:
  return null;

}
}

}

/// @nodoc


class DiaryCreated implements DiaryEvent {
  const DiaryCreated(this.diary);
  

 final  Diary diary;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryCreatedCopyWith<DiaryCreated> get copyWith => _$DiaryCreatedCopyWithImpl<DiaryCreated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryCreated&&(identical(other.diary, diary) || other.diary == diary));
}


@override
int get hashCode => Object.hash(runtimeType,diary);

@override
String toString() {
  return 'DiaryEvent.created(diary: $diary)';
}


}

/// @nodoc
abstract mixin class $DiaryCreatedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryCreatedCopyWith(DiaryCreated value, $Res Function(DiaryCreated) _then) = _$DiaryCreatedCopyWithImpl;
@useResult
$Res call({
 Diary diary
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
@pragma('vm:prefer-inline') $Res call({Object? diary = null,}) {
  return _then(DiaryCreated(
null == diary ? _self.diary : diary // ignore: cast_nullable_to_non_nullable
as Diary,
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
  const DiaryUpdated(this.diary);
  

 final  Diary diary;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryUpdatedCopyWith<DiaryUpdated> get copyWith => _$DiaryUpdatedCopyWithImpl<DiaryUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryUpdated&&(identical(other.diary, diary) || other.diary == diary));
}


@override
int get hashCode => Object.hash(runtimeType,diary);

@override
String toString() {
  return 'DiaryEvent.updated(diary: $diary)';
}


}

/// @nodoc
abstract mixin class $DiaryUpdatedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryUpdatedCopyWith(DiaryUpdated value, $Res Function(DiaryUpdated) _then) = _$DiaryUpdatedCopyWithImpl;
@useResult
$Res call({
 Diary diary
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
@pragma('vm:prefer-inline') $Res call({Object? diary = null,}) {
  return _then(DiaryUpdated(
null == diary ? _self.diary : diary // ignore: cast_nullable_to_non_nullable
as Diary,
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
  const DiaryDeleted(this.isarId);
  

 final  int isarId;

/// Create a copy of DiaryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaryDeletedCopyWith<DiaryDeleted> get copyWith => _$DiaryDeletedCopyWithImpl<DiaryDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryDeleted&&(identical(other.isarId, isarId) || other.isarId == isarId));
}


@override
int get hashCode => Object.hash(runtimeType,isarId);

@override
String toString() {
  return 'DiaryEvent.deleted(isarId: $isarId)';
}


}

/// @nodoc
abstract mixin class $DiaryDeletedCopyWith<$Res> implements $DiaryEventCopyWith<$Res> {
  factory $DiaryDeletedCopyWith(DiaryDeleted value, $Res Function(DiaryDeleted) _then) = _$DiaryDeletedCopyWithImpl;
@useResult
$Res call({
 int isarId
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
@pragma('vm:prefer-inline') $Res call({Object? isarId = null,}) {
  return _then(DiaryDeleted(
null == isarId ? _self.isarId : isarId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
