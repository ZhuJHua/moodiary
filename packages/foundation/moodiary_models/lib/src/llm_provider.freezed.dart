// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LlmProvider {

@Id() String get id; String get name;/// 协议类型 id，取值见 [AssistantProviderType.id]（'openai' / 'anthropic'）。
 String get type;/// 自定义 baseUrl，留空表示使用该协议官方端点。
 String get baseUrl; String get model; DateTime get createdAt;/// 列表排序用，越小越靠前。
 int get sortOrder;
/// Create a copy of LlmProvider
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmProviderCopyWith<LlmProvider> get copyWith => _$LlmProviderCopyWithImpl<LlmProvider>(this as LlmProvider, _$identity);

  /// Serializes this LlmProvider to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,baseUrl,model,createdAt,sortOrder);

@override
String toString() {
  return 'LlmProvider(id: $id, name: $name, type: $type, baseUrl: $baseUrl, model: $model, createdAt: $createdAt, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $LlmProviderCopyWith<$Res>  {
  factory $LlmProviderCopyWith(LlmProvider value, $Res Function(LlmProvider) _then) = _$LlmProviderCopyWithImpl;
@useResult
$Res call({
@Id() String id, String name, String type, String baseUrl, String model, DateTime createdAt, int sortOrder
});




}
/// @nodoc
class _$LlmProviderCopyWithImpl<$Res>
    implements $LlmProviderCopyWith<$Res> {
  _$LlmProviderCopyWithImpl(this._self, this._then);

  final LlmProvider _self;
  final $Res Function(LlmProvider) _then;

/// Create a copy of LlmProvider
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? baseUrl = null,Object? model = null,Object? createdAt = null,Object? sortOrder = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmProvider].
extension LlmProviderPatterns on LlmProvider {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmProvider value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmProvider value)  $default,){
final _that = this;
switch (_that) {
case _LlmProvider():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmProvider value)?  $default,){
final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@Id()  String id,  String name,  String type,  String baseUrl,  String model,  DateTime createdAt,  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.model,_that.createdAt,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@Id()  String id,  String name,  String type,  String baseUrl,  String model,  DateTime createdAt,  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _LlmProvider():
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.model,_that.createdAt,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@Id()  String id,  String name,  String type,  String baseUrl,  String model,  DateTime createdAt,  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.model,_that.createdAt,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmProvider implements LlmProvider {
  const _LlmProvider({@Id() required this.id, required this.name, required this.type, required this.baseUrl, required this.model, required this.createdAt, required this.sortOrder});
  factory _LlmProvider.fromJson(Map<String, dynamic> json) => _$LlmProviderFromJson(json);

@override@Id() final  String id;
@override final  String name;
/// 协议类型 id，取值见 [AssistantProviderType.id]（'openai' / 'anthropic'）。
@override final  String type;
/// 自定义 baseUrl，留空表示使用该协议官方端点。
@override final  String baseUrl;
@override final  String model;
@override final  DateTime createdAt;
/// 列表排序用，越小越靠前。
@override final  int sortOrder;

/// Create a copy of LlmProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmProviderCopyWith<_LlmProvider> get copyWith => __$LlmProviderCopyWithImpl<_LlmProvider>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmProviderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,baseUrl,model,createdAt,sortOrder);

@override
String toString() {
  return 'LlmProvider(id: $id, name: $name, type: $type, baseUrl: $baseUrl, model: $model, createdAt: $createdAt, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$LlmProviderCopyWith<$Res> implements $LlmProviderCopyWith<$Res> {
  factory _$LlmProviderCopyWith(_LlmProvider value, $Res Function(_LlmProvider) _then) = __$LlmProviderCopyWithImpl;
@override @useResult
$Res call({
@Id() String id, String name, String type, String baseUrl, String model, DateTime createdAt, int sortOrder
});




}
/// @nodoc
class __$LlmProviderCopyWithImpl<$Res>
    implements _$LlmProviderCopyWith<$Res> {
  __$LlmProviderCopyWithImpl(this._self, this._then);

  final _LlmProvider _self;
  final $Res Function(_LlmProvider) _then;

/// Create a copy of LlmProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? baseUrl = null,Object? model = null,Object? createdAt = null,Object? sortOrder = null,}) {
  return _then(_LlmProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
