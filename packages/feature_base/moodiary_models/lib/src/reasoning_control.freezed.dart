// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reasoning_control.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReasoningControl {

 ReasoningControlType get type;/// effort 型的档位。取值来自 models.dev，可能含
/// `null` / `none` / `minimal` / `low` / `medium` / `high` / `xhigh` / `max` / `default`。
 List<String> get values;/// budget_tokens 型的下界 / 上界（目录只在核实过时才给）。
 int? get min; int? get max;
/// Create a copy of ReasoningControl
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningControlCopyWith<ReasoningControl> get copyWith => _$ReasoningControlCopyWithImpl<ReasoningControl>(this as ReasoningControl, _$identity);

  /// Serializes this ReasoningControl to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReasoningControl;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningControl&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.values, _this.values)&&(identical(other.min, _this.min) || other.min == _this.min)&&(identical(other.max, _this.max) || other.max == _this.max));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReasoningControl;
  return Object.hash(runtimeType,_this.type,const DeepCollectionEquality().hash(_this.values),_this.min,_this.max);
}

@override
String toString() {
  final _this = this as ReasoningControl;
  return 'ReasoningControl(type: ${_this.type}, values: ${_this.values}, min: ${_this.min}, max: ${_this.max})';
}


}

/// @nodoc
abstract mixin class $ReasoningControlCopyWith<$Res>  {
  factory $ReasoningControlCopyWith(ReasoningControl value, $Res Function(ReasoningControl) _then) = _$ReasoningControlCopyWithImpl;
@useResult
$Res call({
 ReasoningControlType type, List<String> values, int? min, int? max
});




}
/// @nodoc
class _$ReasoningControlCopyWithImpl<$Res>
    implements $ReasoningControlCopyWith<$Res> {
  _$ReasoningControlCopyWithImpl(this._self, this._then);

  final ReasoningControl _self;
  final $Res Function(ReasoningControl) _then;

/// Create a copy of ReasoningControl
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? values = null,Object? min = freezed,Object? max = freezed,}) {
  return _then(ReasoningControl(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReasoningControlType,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<String>,min: freezed == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as int?,max: freezed == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningControl].
extension ReasoningControlPatterns on ReasoningControl {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningControl value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningControl() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningControl value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningControl():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningControl value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningControl() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReasoningControlType type,  List<String> values,  int? min,  int? max)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningControl() when $default != null:
return $default(_that.type,_that.values,_that.min,_that.max);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReasoningControlType type,  List<String> values,  int? min,  int? max)  $default,) {final _that = this;
switch (_that) {
case _ReasoningControl():
return $default(_that.type,_that.values,_that.min,_that.max);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReasoningControlType type,  List<String> values,  int? min,  int? max)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningControl() when $default != null:
return $default(_that.type,_that.values,_that.min,_that.max);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReasoningControl extends ReasoningControl {
  const _ReasoningControl({required this.type,  List<String> values = const <String>[], this.min, this.max}): _values = values,super._();
  factory _ReasoningControl.fromJson(Map<String, dynamic> json) => _$ReasoningControlFromJson(json);

@override final  ReasoningControlType type;
/// effort 型的档位。取值来自 models.dev，可能含
/// `null` / `none` / `minimal` / `low` / `medium` / `high` / `xhigh` / `max` / `default`。
 final  List<String> _values;
/// effort 型的档位。取值来自 models.dev，可能含
/// `null` / `none` / `minimal` / `low` / `medium` / `high` / `xhigh` / `max` / `default`。
@override@JsonKey() List<String> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}

/// budget_tokens 型的下界 / 上界（目录只在核实过时才给）。
@override final  int? min;
@override final  int? max;

/// Create a copy of ReasoningControl
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningControlCopyWith<_ReasoningControl> get copyWith => __$ReasoningControlCopyWithImpl<_ReasoningControl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReasoningControlToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningControl&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.values, _values)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_values),min,max);
}

@override
String toString() {
    return 'ReasoningControl(type: $type, values: $values, min: $min, max: $max)';
}


}

/// @nodoc
abstract mixin class _$ReasoningControlCopyWith<$Res> implements $ReasoningControlCopyWith<$Res> {
  factory _$ReasoningControlCopyWith(_ReasoningControl value, $Res Function(_ReasoningControl) _then) = __$ReasoningControlCopyWithImpl;
@override @useResult
$Res call({
 ReasoningControlType type, List<String> values, int? min, int? max
});




}
/// @nodoc
class __$ReasoningControlCopyWithImpl<$Res>
    implements _$ReasoningControlCopyWith<$Res> {
  __$ReasoningControlCopyWithImpl(this._self, this._then);

  final _ReasoningControl _self;
  final $Res Function(_ReasoningControl) _then;

/// Create a copy of ReasoningControl
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? values = null,Object? min = freezed,Object? max = freezed,}) {
  return _then(_ReasoningControl(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReasoningControlType,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<String>,min: freezed == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as int?,max: freezed == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
