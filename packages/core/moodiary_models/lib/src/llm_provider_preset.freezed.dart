// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_provider_preset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LlmProviderPreset {

 String get id; String get name;/// 映射到 rig 协议（openai / anthropic）。
 AssistantProviderType get protocol;/// 官方端点为空串（rig 侧留空即用协议官方端点），来自 models.dev `api`。
 String get baseUrl; List<LlmModelPreset> get models;/// 文档 / 定价页链接，来自 `doc`，兼作「获取 API Key」入口。
 String? get docUrl;/// API Key 的环境变量名（如 `ANTHROPIC_API_KEY`），来自 `env`，作提示用。
 List<String> get env;/// 供应商 logo（`https://models.dev/logos/<id>.svg`）。
 String? get logoUrl;
/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmProviderPresetCopyWith<LlmProviderPreset> get copyWith => _$LlmProviderPresetCopyWithImpl<LlmProviderPreset>(this as LlmProviderPreset, _$identity);

  /// Serializes this LlmProviderPreset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmProviderPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.docUrl, docUrl) || other.docUrl == docUrl)&&const DeepCollectionEquality().equals(other.env, env)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,protocol,baseUrl,const DeepCollectionEquality().hash(models),docUrl,const DeepCollectionEquality().hash(env),logoUrl);

@override
String toString() {
  return 'LlmProviderPreset(id: $id, name: $name, protocol: $protocol, baseUrl: $baseUrl, models: $models, docUrl: $docUrl, env: $env, logoUrl: $logoUrl)';
}


}

/// @nodoc
abstract mixin class $LlmProviderPresetCopyWith<$Res>  {
  factory $LlmProviderPresetCopyWith(LlmProviderPreset value, $Res Function(LlmProviderPreset) _then) = _$LlmProviderPresetCopyWithImpl;
@useResult
$Res call({
 String id, String name, AssistantProviderType protocol, String baseUrl, List<LlmModelPreset> models, String? docUrl, List<String> env, String? logoUrl
});




}
/// @nodoc
class _$LlmProviderPresetCopyWithImpl<$Res>
    implements $LlmProviderPresetCopyWith<$Res> {
  _$LlmProviderPresetCopyWithImpl(this._self, this._then);

  final LlmProviderPreset _self;
  final $Res Function(LlmProviderPreset) _then;

/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? protocol = null,Object? baseUrl = null,Object? models = null,Object? docUrl = freezed,Object? env = null,Object? logoUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<LlmModelPreset>,docUrl: freezed == docUrl ? _self.docUrl : docUrl // ignore: cast_nullable_to_non_nullable
as String?,env: null == env ? _self.env : env // ignore: cast_nullable_to_non_nullable
as List<String>,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmProviderPreset].
extension LlmProviderPresetPatterns on LlmProviderPreset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmProviderPreset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmProviderPreset value)  $default,){
final _that = this;
switch (_that) {
case _LlmProviderPreset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmProviderPreset value)?  $default,){
final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  List<LlmModelPreset> models,  String? docUrl,  List<String> env,  String? logoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.models,_that.docUrl,_that.env,_that.logoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  List<LlmModelPreset> models,  String? docUrl,  List<String> env,  String? logoUrl)  $default,) {final _that = this;
switch (_that) {
case _LlmProviderPreset():
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.models,_that.docUrl,_that.env,_that.logoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AssistantProviderType protocol,  String baseUrl,  List<LlmModelPreset> models,  String? docUrl,  List<String> env,  String? logoUrl)?  $default,) {final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
return $default(_that.id,_that.name,_that.protocol,_that.baseUrl,_that.models,_that.docUrl,_that.env,_that.logoUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmProviderPreset extends LlmProviderPreset {
  const _LlmProviderPreset({required this.id, required this.name, required this.protocol, required this.baseUrl, required final  List<LlmModelPreset> models, this.docUrl, final  List<String> env = const <String>[], this.logoUrl}): _models = models,_env = env,super._();
  factory _LlmProviderPreset.fromJson(Map<String, dynamic> json) => _$LlmProviderPresetFromJson(json);

@override final  String id;
@override final  String name;
/// 映射到 rig 协议（openai / anthropic）。
@override final  AssistantProviderType protocol;
/// 官方端点为空串（rig 侧留空即用协议官方端点），来自 models.dev `api`。
@override final  String baseUrl;
 final  List<LlmModelPreset> _models;
@override List<LlmModelPreset> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

/// 文档 / 定价页链接，来自 `doc`，兼作「获取 API Key」入口。
@override final  String? docUrl;
/// API Key 的环境变量名（如 `ANTHROPIC_API_KEY`），来自 `env`，作提示用。
 final  List<String> _env;
/// API Key 的环境变量名（如 `ANTHROPIC_API_KEY`），来自 `env`，作提示用。
@override@JsonKey() List<String> get env {
  if (_env is EqualUnmodifiableListView) return _env;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_env);
}

/// 供应商 logo（`https://models.dev/logos/<id>.svg`）。
@override final  String? logoUrl;

/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmProviderPresetCopyWith<_LlmProviderPreset> get copyWith => __$LlmProviderPresetCopyWithImpl<_LlmProviderPreset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmProviderPresetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmProviderPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.docUrl, docUrl) || other.docUrl == docUrl)&&const DeepCollectionEquality().equals(other._env, _env)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,protocol,baseUrl,const DeepCollectionEquality().hash(_models),docUrl,const DeepCollectionEquality().hash(_env),logoUrl);

@override
String toString() {
  return 'LlmProviderPreset(id: $id, name: $name, protocol: $protocol, baseUrl: $baseUrl, models: $models, docUrl: $docUrl, env: $env, logoUrl: $logoUrl)';
}


}

/// @nodoc
abstract mixin class _$LlmProviderPresetCopyWith<$Res> implements $LlmProviderPresetCopyWith<$Res> {
  factory _$LlmProviderPresetCopyWith(_LlmProviderPreset value, $Res Function(_LlmProviderPreset) _then) = __$LlmProviderPresetCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AssistantProviderType protocol, String baseUrl, List<LlmModelPreset> models, String? docUrl, List<String> env, String? logoUrl
});




}
/// @nodoc
class __$LlmProviderPresetCopyWithImpl<$Res>
    implements _$LlmProviderPresetCopyWith<$Res> {
  __$LlmProviderPresetCopyWithImpl(this._self, this._then);

  final _LlmProviderPreset _self;
  final $Res Function(_LlmProviderPreset) _then;

/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? protocol = null,Object? baseUrl = null,Object? models = null,Object? docUrl = freezed,Object? env = null,Object? logoUrl = freezed,}) {
  return _then(_LlmProviderPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<LlmModelPreset>,docUrl: freezed == docUrl ? _self.docUrl : docUrl // ignore: cast_nullable_to_non_nullable
as String?,env: null == env ? _self._env : env // ignore: cast_nullable_to_non_nullable
as List<String>,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
