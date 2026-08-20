// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoryEvent {

 bool get fromSync;
/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryEventCopyWith<CategoryEvent> get copyWith => _$CategoryEventCopyWithImpl<CategoryEvent>(this as CategoryEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryEvent&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,fromSync);

@override
String toString() {
  return 'CategoryEvent(fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $CategoryEventCopyWith<$Res>  {
  factory $CategoryEventCopyWith(CategoryEvent value, $Res Function(CategoryEvent) _then) = _$CategoryEventCopyWithImpl;
@useResult
$Res call({
 bool fromSync
});




}
/// @nodoc
class _$CategoryEventCopyWithImpl<$Res>
    implements $CategoryEventCopyWith<$Res> {
  _$CategoryEventCopyWithImpl(this._self, this._then);

  final CategoryEvent _self;
  final $Res Function(CategoryEvent) _then;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromSync = null,}) {
  return _then(_self.copyWith(
fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryEvent].
extension CategoryEventPatterns on CategoryEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CategoryUpserted value)?  upserted,TResult Function( CategoryDeleted value)?  deleted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that);case CategoryDeleted() when deleted != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CategoryUpserted value)  upserted,required TResult Function( CategoryDeleted value)  deleted,}){
final _that = this;
switch (_that) {
case CategoryUpserted():
return upserted(_that);case CategoryDeleted():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CategoryUpserted value)?  upserted,TResult? Function( CategoryDeleted value)?  deleted,}){
final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that);case CategoryDeleted() when deleted != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Category category,  bool fromSync)?  upserted,TResult Function( String id,  bool fromSync)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that.category,_that.fromSync);case CategoryDeleted() when deleted != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Category category,  bool fromSync)  upserted,required TResult Function( String id,  bool fromSync)  deleted,}) {final _that = this;
switch (_that) {
case CategoryUpserted():
return upserted(_that.category,_that.fromSync);case CategoryDeleted():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Category category,  bool fromSync)?  upserted,TResult? Function( String id,  bool fromSync)?  deleted,}) {final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that.category,_that.fromSync);case CategoryDeleted() when deleted != null:
return deleted(_that.id,_that.fromSync);case _:
  return null;

}
}

}

/// @nodoc


class CategoryUpserted implements CategoryEvent {
  const CategoryUpserted(this.category, {this.fromSync = false});
  

 final  Category category;
@override@JsonKey() final  bool fromSync;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryUpsertedCopyWith<CategoryUpserted> get copyWith => _$CategoryUpsertedCopyWithImpl<CategoryUpserted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryUpserted&&(identical(other.category, category) || other.category == category)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,category,fromSync);

@override
String toString() {
  return 'CategoryEvent.upserted(category: $category, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $CategoryUpsertedCopyWith<$Res> implements $CategoryEventCopyWith<$Res> {
  factory $CategoryUpsertedCopyWith(CategoryUpserted value, $Res Function(CategoryUpserted) _then) = _$CategoryUpsertedCopyWithImpl;
@override @useResult
$Res call({
 Category category, bool fromSync
});


$CategoryCopyWith<$Res> get category;

}
/// @nodoc
class _$CategoryUpsertedCopyWithImpl<$Res>
    implements $CategoryUpsertedCopyWith<$Res> {
  _$CategoryUpsertedCopyWithImpl(this._self, this._then);

  final CategoryUpserted _self;
  final $Res Function(CategoryUpserted) _then;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? fromSync = null,}) {
  return _then(CategoryUpserted(
null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryCopyWith<$Res> get category {
  
  return $CategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

/// @nodoc


class CategoryDeleted implements CategoryEvent {
  const CategoryDeleted(this.id, {this.fromSync = false});
  

 final  String id;
@override@JsonKey() final  bool fromSync;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryDeletedCopyWith<CategoryDeleted> get copyWith => _$CategoryDeletedCopyWithImpl<CategoryDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryDeleted&&(identical(other.id, id) || other.id == id)&&(identical(other.fromSync, fromSync) || other.fromSync == fromSync));
}


@override
int get hashCode => Object.hash(runtimeType,id,fromSync);

@override
String toString() {
  return 'CategoryEvent.deleted(id: $id, fromSync: $fromSync)';
}


}

/// @nodoc
abstract mixin class $CategoryDeletedCopyWith<$Res> implements $CategoryEventCopyWith<$Res> {
  factory $CategoryDeletedCopyWith(CategoryDeleted value, $Res Function(CategoryDeleted) _then) = _$CategoryDeletedCopyWithImpl;
@override @useResult
$Res call({
 String id, bool fromSync
});




}
/// @nodoc
class _$CategoryDeletedCopyWithImpl<$Res>
    implements $CategoryDeletedCopyWith<$Res> {
  _$CategoryDeletedCopyWithImpl(this._self, this._then);

  final CategoryDeleted _self;
  final $Res Function(CategoryDeleted) _then;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromSync = null,}) {
  return _then(CategoryDeleted(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromSync: null == fromSync ? _self.fromSync : fromSync // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
