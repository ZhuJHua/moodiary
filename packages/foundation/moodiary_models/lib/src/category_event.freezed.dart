// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoryEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CategoryEvent()';
}


}

/// @nodoc
class $CategoryEventCopyWith<$Res>  {
$CategoryEventCopyWith(CategoryEvent _, $Res Function(CategoryEvent) __);
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Category category)?  upserted,TResult Function( String id)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that.category);case CategoryDeleted() when deleted != null:
return deleted(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Category category)  upserted,required TResult Function( String id)  deleted,}) {final _that = this;
switch (_that) {
case CategoryUpserted():
return upserted(_that.category);case CategoryDeleted():
return deleted(_that.id);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Category category)?  upserted,TResult? Function( String id)?  deleted,}) {final _that = this;
switch (_that) {
case CategoryUpserted() when upserted != null:
return upserted(_that.category);case CategoryDeleted() when deleted != null:
return deleted(_that.id);case _:
  return null;

}
}

}

/// @nodoc


class CategoryUpserted implements CategoryEvent {
  const CategoryUpserted(this.category);
  

 final  Category category;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryUpsertedCopyWith<CategoryUpserted> get copyWith => _$CategoryUpsertedCopyWithImpl<CategoryUpserted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryUpserted&&(identical(other.category, category) || other.category == category));
}


@override
int get hashCode => Object.hash(runtimeType,category);

@override
String toString() {
  return 'CategoryEvent.upserted(category: $category)';
}


}

/// @nodoc
abstract mixin class $CategoryUpsertedCopyWith<$Res> implements $CategoryEventCopyWith<$Res> {
  factory $CategoryUpsertedCopyWith(CategoryUpserted value, $Res Function(CategoryUpserted) _then) = _$CategoryUpsertedCopyWithImpl;
@useResult
$Res call({
 Category category
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
@pragma('vm:prefer-inline') $Res call({Object? category = null,}) {
  return _then(CategoryUpserted(
null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,
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
  const CategoryDeleted(this.id);
  

 final  String id;

/// Create a copy of CategoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryDeletedCopyWith<CategoryDeleted> get copyWith => _$CategoryDeletedCopyWithImpl<CategoryDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryDeleted&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'CategoryEvent.deleted(id: $id)';
}


}

/// @nodoc
abstract mixin class $CategoryDeletedCopyWith<$Res> implements $CategoryEventCopyWith<$Res> {
  factory $CategoryDeletedCopyWith(CategoryDeleted value, $Res Function(CategoryDeleted) _then) = _$CategoryDeletedCopyWithImpl;
@useResult
$Res call({
 String id
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
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(CategoryDeleted(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
