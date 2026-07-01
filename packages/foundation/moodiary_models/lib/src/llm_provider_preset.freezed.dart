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

 String get id; AssistantProviderType get protocol;/// localeCode -> 展示名，必含 `default`。
 Map<String, String> get name; String get baseUrl; List<String> get models; String? get apiKeyUrl; String? get icon;
/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmProviderPresetCopyWith<LlmProviderPreset> get copyWith => _$LlmProviderPresetCopyWithImpl<LlmProviderPreset>(this as LlmProviderPreset, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmProviderPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&const DeepCollectionEquality().equals(other.name, name)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.apiKeyUrl, apiKeyUrl) || other.apiKeyUrl == apiKeyUrl)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,id,protocol,const DeepCollectionEquality().hash(name),baseUrl,const DeepCollectionEquality().hash(models),apiKeyUrl,icon);

@override
String toString() {
  return 'LlmProviderPreset(id: $id, protocol: $protocol, name: $name, baseUrl: $baseUrl, models: $models, apiKeyUrl: $apiKeyUrl, icon: $icon)';
}


}

/// @nodoc
abstract mixin class $LlmProviderPresetCopyWith<$Res>  {
  factory $LlmProviderPresetCopyWith(LlmProviderPreset value, $Res Function(LlmProviderPreset) _then) = _$LlmProviderPresetCopyWithImpl;
@useResult
$Res call({
 String id, AssistantProviderType protocol, Map<String, String> name, String baseUrl, List<String> models, String? apiKeyUrl, String? icon
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? protocol = null,Object? name = null,Object? baseUrl = null,Object? models = null,Object? apiKeyUrl = freezed,Object? icon = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as Map<String, String>,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<String>,apiKeyUrl: freezed == apiKeyUrl ? _self.apiKeyUrl : apiKeyUrl // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AssistantProviderType protocol,  Map<String, String> name,  String baseUrl,  List<String> models,  String? apiKeyUrl,  String? icon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
return $default(_that.id,_that.protocol,_that.name,_that.baseUrl,_that.models,_that.apiKeyUrl,_that.icon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AssistantProviderType protocol,  Map<String, String> name,  String baseUrl,  List<String> models,  String? apiKeyUrl,  String? icon)  $default,) {final _that = this;
switch (_that) {
case _LlmProviderPreset():
return $default(_that.id,_that.protocol,_that.name,_that.baseUrl,_that.models,_that.apiKeyUrl,_that.icon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AssistantProviderType protocol,  Map<String, String> name,  String baseUrl,  List<String> models,  String? apiKeyUrl,  String? icon)?  $default,) {final _that = this;
switch (_that) {
case _LlmProviderPreset() when $default != null:
return $default(_that.id,_that.protocol,_that.name,_that.baseUrl,_that.models,_that.apiKeyUrl,_that.icon);case _:
  return null;

}
}

}

/// @nodoc


class _LlmProviderPreset extends LlmProviderPreset {
  const _LlmProviderPreset({required this.id, required this.protocol, required final  Map<String, String> name, required this.baseUrl, required final  List<String> models, this.apiKeyUrl, this.icon}): _name = name,_models = models,super._();
  

@override final  String id;
@override final  AssistantProviderType protocol;
/// localeCode -> 展示名，必含 `default`。
 final  Map<String, String> _name;
/// localeCode -> 展示名，必含 `default`。
@override Map<String, String> get name {
  if (_name is EqualUnmodifiableMapView) return _name;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_name);
}

@override final  String baseUrl;
 final  List<String> _models;
@override List<String> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? apiKeyUrl;
@override final  String? icon;

/// Create a copy of LlmProviderPreset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmProviderPresetCopyWith<_LlmProviderPreset> get copyWith => __$LlmProviderPresetCopyWithImpl<_LlmProviderPreset>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmProviderPreset&&(identical(other.id, id) || other.id == id)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&const DeepCollectionEquality().equals(other._name, _name)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.apiKeyUrl, apiKeyUrl) || other.apiKeyUrl == apiKeyUrl)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,id,protocol,const DeepCollectionEquality().hash(_name),baseUrl,const DeepCollectionEquality().hash(_models),apiKeyUrl,icon);

@override
String toString() {
  return 'LlmProviderPreset(id: $id, protocol: $protocol, name: $name, baseUrl: $baseUrl, models: $models, apiKeyUrl: $apiKeyUrl, icon: $icon)';
}


}

/// @nodoc
abstract mixin class _$LlmProviderPresetCopyWith<$Res> implements $LlmProviderPresetCopyWith<$Res> {
  factory _$LlmProviderPresetCopyWith(_LlmProviderPreset value, $Res Function(_LlmProviderPreset) _then) = __$LlmProviderPresetCopyWithImpl;
@override @useResult
$Res call({
 String id, AssistantProviderType protocol, Map<String, String> name, String baseUrl, List<String> models, String? apiKeyUrl, String? icon
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? protocol = null,Object? name = null,Object? baseUrl = null,Object? models = null,Object? apiKeyUrl = freezed,Object? icon = freezed,}) {
  return _then(_LlmProviderPreset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as AssistantProviderType,name: null == name ? _self._name : name // ignore: cast_nullable_to_non_nullable
as Map<String, String>,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<String>,apiKeyUrl: freezed == apiKeyUrl ? _self.apiKeyUrl : apiKeyUrl // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
