// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LlmProvider {

 String get id; String get name;/// 仅自定义供应商：[AssistantProviderType.id]。
 String get type;/// 仅自定义供应商：端点根地址。
 String get baseUrl;/// 新会话默认选中的模型 id。
 String get defaultModel; DateTime get createdAt; int get sortOrder;/// 这一条是从哪个 models.dev 预设建出来的（`LlmProviderPreset.id`，如 `deepseek`）。
/// **自定义供应商恒为空串**，全仓靠 `isEmpty` 区分两类：空 = 不查在线目录、
/// 不拉 logo、baseUrl 与协议可改。它不是键，重复不要紧 —— 身份是 [id]（uuid v7）。
 String get presetId;/// 仅自定义供应商：可选模型 id 列表（`GET {base}/models` 拉到的 + 手工补的）。
/// 落库是为了让选择器离线可用 —— 每次开都联网拉一遍不可接受。
 List<String> get models;/// 模型能力标记。preset 供应商以在线目录为准（逐模型），这里仅对**自定义**供应商
/// 生效且对其下所有模型一视同仁。三者都默认 false（opt-in）。
 bool get toolCall; bool get reasoning; bool get attachment;
/// Create a copy of LlmProvider
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmProviderCopyWith<LlmProvider> get copyWith => _$LlmProviderCopyWithImpl<LlmProvider>(this as LlmProvider, _$identity);

  /// Serializes this LlmProvider to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.defaultModel, defaultModel) || other.defaultModel == defaultModel)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.presetId, presetId) || other.presetId == presetId)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,baseUrl,defaultModel,createdAt,sortOrder,presetId,const DeepCollectionEquality().hash(models),toolCall,reasoning,attachment);

@override
String toString() {
  return 'LlmProvider(id: $id, name: $name, type: $type, baseUrl: $baseUrl, defaultModel: $defaultModel, createdAt: $createdAt, sortOrder: $sortOrder, presetId: $presetId, models: $models, toolCall: $toolCall, reasoning: $reasoning, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class $LlmProviderCopyWith<$Res>  {
  factory $LlmProviderCopyWith(LlmProvider value, $Res Function(LlmProvider) _then) = _$LlmProviderCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String baseUrl, String defaultModel, DateTime createdAt, int sortOrder, String presetId, List<String> models, bool toolCall, bool reasoning, bool attachment
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? baseUrl = null,Object? defaultModel = null,Object? createdAt = null,Object? sortOrder = null,Object? presetId = null,Object? models = null,Object? toolCall = null,Object? reasoning = null,Object? attachment = null,}) {
  return _then(LlmProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultModel: null == defaultModel ? _self.defaultModel : defaultModel // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,presetId: null == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<String>,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String baseUrl,  String defaultModel,  DateTime createdAt,  int sortOrder,  String presetId,  List<String> models,  bool toolCall,  bool reasoning,  bool attachment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.defaultModel,_that.createdAt,_that.sortOrder,_that.presetId,_that.models,_that.toolCall,_that.reasoning,_that.attachment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String baseUrl,  String defaultModel,  DateTime createdAt,  int sortOrder,  String presetId,  List<String> models,  bool toolCall,  bool reasoning,  bool attachment)  $default,) {final _that = this;
switch (_that) {
case _LlmProvider():
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.defaultModel,_that.createdAt,_that.sortOrder,_that.presetId,_that.models,_that.toolCall,_that.reasoning,_that.attachment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String baseUrl,  String defaultModel,  DateTime createdAt,  int sortOrder,  String presetId,  List<String> models,  bool toolCall,  bool reasoning,  bool attachment)?  $default,) {final _that = this;
switch (_that) {
case _LlmProvider() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.baseUrl,_that.defaultModel,_that.createdAt,_that.sortOrder,_that.presetId,_that.models,_that.toolCall,_that.reasoning,_that.attachment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmProvider extends LlmProvider {
  const _LlmProvider({required this.id, required this.name, required this.type, required this.baseUrl, required this.defaultModel, required this.createdAt, required this.sortOrder, this.presetId = '',  List<String> models = const <String>[], this.toolCall = false, this.reasoning = false, this.attachment = false}): _models = models,super._();
  factory _LlmProvider.fromJson(Map<String, dynamic> json) => _$LlmProviderFromJson(json);

@override final  String id;
@override final  String name;
/// 仅自定义供应商：[AssistantProviderType.id]。
@override final  String type;
/// 仅自定义供应商：端点根地址。
@override final  String baseUrl;
/// 新会话默认选中的模型 id。
@override final  String defaultModel;
@override final  DateTime createdAt;
@override final  int sortOrder;
/// 这一条是从哪个 models.dev 预设建出来的（`LlmProviderPreset.id`，如 `deepseek`）。
/// **自定义供应商恒为空串**，全仓靠 `isEmpty` 区分两类：空 = 不查在线目录、
/// 不拉 logo、baseUrl 与协议可改。它不是键，重复不要紧 —— 身份是 [id]（uuid v7）。
@override@JsonKey() final  String presetId;
/// 仅自定义供应商：可选模型 id 列表（`GET {base}/models` 拉到的 + 手工补的）。
/// 落库是为了让选择器离线可用 —— 每次开都联网拉一遍不可接受。
 final  List<String> _models;
/// 仅自定义供应商：可选模型 id 列表（`GET {base}/models` 拉到的 + 手工补的）。
/// 落库是为了让选择器离线可用 —— 每次开都联网拉一遍不可接受。
@override@JsonKey() List<String> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

/// 模型能力标记。preset 供应商以在线目录为准（逐模型），这里仅对**自定义**供应商
/// 生效且对其下所有模型一视同仁。三者都默认 false（opt-in）。
@override@JsonKey() final  bool toolCall;
@override@JsonKey() final  bool reasoning;
@override@JsonKey() final  bool attachment;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.defaultModel, defaultModel) || other.defaultModel == defaultModel)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.presetId, presetId) || other.presetId == presetId)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,baseUrl,defaultModel,createdAt,sortOrder,presetId,const DeepCollectionEquality().hash(_models),toolCall,reasoning,attachment);

@override
String toString() {
  return 'LlmProvider(id: $id, name: $name, type: $type, baseUrl: $baseUrl, defaultModel: $defaultModel, createdAt: $createdAt, sortOrder: $sortOrder, presetId: $presetId, models: $models, toolCall: $toolCall, reasoning: $reasoning, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class _$LlmProviderCopyWith<$Res> implements $LlmProviderCopyWith<$Res> {
  factory _$LlmProviderCopyWith(_LlmProvider value, $Res Function(_LlmProvider) _then) = __$LlmProviderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String baseUrl, String defaultModel, DateTime createdAt, int sortOrder, String presetId, List<String> models, bool toolCall, bool reasoning, bool attachment
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? baseUrl = null,Object? defaultModel = null,Object? createdAt = null,Object? sortOrder = null,Object? presetId = null,Object? models = null,Object? toolCall = null,Object? reasoning = null,Object? attachment = null,}) {
  return _then(_LlmProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultModel: null == defaultModel ? _self.defaultModel : defaultModel // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,presetId: null == presetId ? _self.presetId : presetId // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<String>,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as bool,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
