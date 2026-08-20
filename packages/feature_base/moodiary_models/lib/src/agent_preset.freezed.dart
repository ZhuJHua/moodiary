// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_preset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentPreset {

@Id() String get id; String get name; String get description;/// 人格文本（system prompt 的 order-0 段），上限由写入方截断。
 String get persona;/// 本预设挂载的工具 id 子集（dsh：预设声明它 mount 哪些工具）。
/// null = 全部（跟随出厂全集，含未来新增）；空列表 = 一个工具都不挂。
 List<String>? get tools; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of AgentPreset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentPresetCopyWith<AgentPreset> get copyWith => _$AgentPresetCopyWithImpl<AgentPreset>(this as AgentPreset, _$identity);

  /// Serializes this AgentPreset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.persona, persona) || other.persona == persona)&&const DeepCollectionEquality().equals(other.tools, tools)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,persona,const DeepCollectionEquality().hash(tools),createdAt,updatedAt);

@override
String toString() {
  return 'AgentPreset(id: $id, name: $name, description: $description, persona: $persona, tools: $tools, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AgentPresetCopyWith<$Res>  {
  factory $AgentPresetCopyWith(AgentPreset value, $Res Function(AgentPreset) _then) = _$AgentPresetCopyWithImpl;
@useResult
$Res call({
@Id() String id, String name, String description, String persona, List<String>? tools, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$AgentPresetCopyWithImpl<$Res>
    implements $AgentPresetCopyWith<$Res> {
  _$AgentPresetCopyWithImpl(this._self, this._then);

  final AgentPreset _self;
  final $Res Function(AgentPreset) _then;

/// Create a copy of AgentPreset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? persona = null,Object? tools = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(AgentPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as String,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentPreset].
extension AgentPresetPatterns on AgentPreset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentPreset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentPreset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentPreset value)  $default,){
final _that = this;
switch (_that) {
case _AgentPreset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentPreset value)?  $default,){
final _that = this;
switch (_that) {
case _AgentPreset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id,  String name,  String description,  String persona,  List<String>? tools,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentPreset() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.persona,_that.tools,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id,  String name,  String description,  String persona,  List<String>? tools,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AgentPreset():
return $default(_that.id,_that.name,_that.description,_that.persona,_that.tools,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id,  String name,  String description,  String persona,  List<String>? tools,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AgentPreset() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.persona,_that.tools,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentPreset implements AgentPreset {
  const _AgentPreset({@Id() required this.id, required this.name, this.description = '', required this.persona,  List<String>? tools, required this.createdAt, required this.updatedAt}): _tools = tools;
  factory _AgentPreset.fromJson(Map<String, dynamic> json) => _$AgentPresetFromJson(json);

@override@Id() final  String id;
@override final  String name;
@override@JsonKey() final  String description;
/// 人格文本（system prompt 的 order-0 段），上限由写入方截断。
@override final  String persona;
/// 本预设挂载的工具 id 子集（dsh：预设声明它 mount 哪些工具）。
/// null = 全部（跟随出厂全集，含未来新增）；空列表 = 一个工具都不挂。
 final  List<String>? _tools;
/// 本预设挂载的工具 id 子集（dsh：预设声明它 mount 哪些工具）。
/// null = 全部（跟随出厂全集，含未来新增）；空列表 = 一个工具都不挂。
@override List<String>? get tools {
  final value = _tools;
  if (value == null) return null;
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of AgentPreset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentPresetCopyWith<_AgentPreset> get copyWith => __$AgentPresetCopyWithImpl<_AgentPreset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentPresetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.persona, persona) || other.persona == persona)&&const DeepCollectionEquality().equals(other._tools, _tools)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,persona,const DeepCollectionEquality().hash(_tools),createdAt,updatedAt);

@override
String toString() {
  return 'AgentPreset(id: $id, name: $name, description: $description, persona: $persona, tools: $tools, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AgentPresetCopyWith<$Res> implements $AgentPresetCopyWith<$Res> {
  factory _$AgentPresetCopyWith(_AgentPreset value, $Res Function(_AgentPreset) _then) = __$AgentPresetCopyWithImpl;
@override @useResult
$Res call({
@Id() String id, String name, String description, String persona, List<String>? tools, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$AgentPresetCopyWithImpl<$Res>
    implements _$AgentPresetCopyWith<$Res> {
  __$AgentPresetCopyWithImpl(this._self, this._then);

  final _AgentPreset _self;
  final $Res Function(_AgentPreset) _then;

/// Create a copy of AgentPreset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? persona = null,Object? tools = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_AgentPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as String,tools: freezed == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
