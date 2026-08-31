// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'memory_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MemoryEntry {

@Id() String get id;/// 记忆类别：`preference`（偏好）| `theme`（反复出现的主题）| `goal`（目标）| `fact`（事实）。
 String get category; String get text; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of MemoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemoryEntryCopyWith<MemoryEntry> get copyWith => _$MemoryEntryCopyWithImpl<MemoryEntry>(this as MemoryEntry, _$identity);

  /// Serializes this MemoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MemoryEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemoryEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MemoryEntry;
  return Object.hash(runtimeType,_this.id,_this.category,_this.text,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as MemoryEntry;
  return 'MemoryEntry(id: ${_this.id}, category: ${_this.category}, text: ${_this.text}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $MemoryEntryCopyWith<$Res>  {
  factory $MemoryEntryCopyWith(MemoryEntry value, $Res Function(MemoryEntry) _then) = _$MemoryEntryCopyWithImpl;
@useResult
$Res call({
@Id() String id, String category, String text, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$MemoryEntryCopyWithImpl<$Res>
    implements $MemoryEntryCopyWith<$Res> {
  _$MemoryEntryCopyWithImpl(this._self, this._then);

  final MemoryEntry _self;
  final $Res Function(MemoryEntry) _then;

/// Create a copy of MemoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? category = null,Object? text = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(MemoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MemoryEntry].
extension MemoryEntryPatterns on MemoryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemoryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _MemoryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _MemoryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id,  String category,  String text,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemoryEntry() when $default != null:
return $default(_that.id,_that.category,_that.text,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id,  String category,  String text,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MemoryEntry():
return $default(_that.id,_that.category,_that.text,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id,  String category,  String text,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MemoryEntry() when $default != null:
return $default(_that.id,_that.category,_that.text,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MemoryEntry implements MemoryEntry {
  const _MemoryEntry({@Id() required this.id, required this.category, required this.text, required this.createdAt, required this.updatedAt});
  factory _MemoryEntry.fromJson(Map<String, dynamic> json) => _$MemoryEntryFromJson(json);

@override@Id() final  String id;
/// 记忆类别：`preference`（偏好）| `theme`（反复出现的主题）| `goal`（目标）| `fact`（事实）。
@override final  String category;
@override final  String text;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of MemoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemoryEntryCopyWith<_MemoryEntry> get copyWith => __$MemoryEntryCopyWithImpl<_MemoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MemoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.category, category) || other.category == category)&&(identical(other.text, text) || other.text == text)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,category,text,createdAt,updatedAt);
}

@override
String toString() {
    return 'MemoryEntry(id: $id, category: $category, text: $text, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MemoryEntryCopyWith<$Res> implements $MemoryEntryCopyWith<$Res> {
  factory _$MemoryEntryCopyWith(_MemoryEntry value, $Res Function(_MemoryEntry) _then) = __$MemoryEntryCopyWithImpl;
@override @useResult
$Res call({
@Id() String id, String category, String text, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$MemoryEntryCopyWithImpl<$Res>
    implements _$MemoryEntryCopyWith<$Res> {
  __$MemoryEntryCopyWithImpl(this._self, this._then);

  final _MemoryEntry _self;
  final $Res Function(_MemoryEntry) _then;

/// Create a copy of MemoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? category = null,Object? text = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_MemoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
