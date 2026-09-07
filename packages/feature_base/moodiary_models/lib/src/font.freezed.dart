// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'font.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Font {

 String get fontFileName; Map<String, dynamic> get fontWghtAxisMap;
/// Create a copy of Font
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FontCopyWith<Font> get copyWith => _$FontCopyWithImpl<Font>(this as Font, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Font;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Font&&(identical(other.fontFileName, _this.fontFileName) || other.fontFileName == _this.fontFileName)&&const DeepCollectionEquality().equals(other.fontWghtAxisMap, _this.fontWghtAxisMap));
}


@override
int get hashCode {
  final _this = this as Font;
  return Object.hash(runtimeType,_this.fontFileName,const DeepCollectionEquality().hash(_this.fontWghtAxisMap));
}

@override
String toString() {
  final _this = this as Font;
  return 'Font(fontFileName: ${_this.fontFileName}, fontWghtAxisMap: ${_this.fontWghtAxisMap})';
}


}

/// @nodoc
abstract mixin class $FontCopyWith<$Res>  {
  factory $FontCopyWith(Font value, $Res Function(Font) _then) = _$FontCopyWithImpl;
@useResult
$Res call({
 String fontFileName, Map<String, dynamic> fontWghtAxisMap
});




}
/// @nodoc
class _$FontCopyWithImpl<$Res>
    implements $FontCopyWith<$Res> {
  _$FontCopyWithImpl(this._self, this._then);

  final Font _self;
  final $Res Function(Font) _then;

/// Create a copy of Font
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fontFileName = null,Object? fontWghtAxisMap = null,}) {
  return _then(Font(
fontFileName: null == fontFileName ? _self.fontFileName : fontFileName // ignore: cast_nullable_to_non_nullable
as String,fontWghtAxisMap: null == fontWghtAxisMap ? _self.fontWghtAxisMap : fontWghtAxisMap // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [Font].
extension FontPatterns on Font {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Font value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Font() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Font value)  $default,){
final _that = this;
switch (_that) {
case _Font():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Font value)?  $default,){
final _that = this;
switch (_that) {
case _Font() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fontFileName,  Map<String, dynamic> fontWghtAxisMap)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Font() when $default != null:
return $default(_that.fontFileName,_that.fontWghtAxisMap);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fontFileName,  Map<String, dynamic> fontWghtAxisMap)  $default,) {final _that = this;
switch (_that) {
case _Font():
return $default(_that.fontFileName,_that.fontWghtAxisMap);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fontFileName,  Map<String, dynamic> fontWghtAxisMap)?  $default,) {final _that = this;
switch (_that) {
case _Font() when $default != null:
return $default(_that.fontFileName,_that.fontWghtAxisMap);case _:
  return null;

}
}

}

/// @nodoc


class _Font extends Font {
  const _Font({required this.fontFileName, required  Map<String, dynamic> fontWghtAxisMap}): _fontWghtAxisMap = fontWghtAxisMap,super._();
  

@override final  String fontFileName;
 final  Map<String, dynamic> _fontWghtAxisMap;
@override Map<String, dynamic> get fontWghtAxisMap {
  if (_fontWghtAxisMap is EqualUnmodifiableMapView) return _fontWghtAxisMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fontWghtAxisMap);
}


/// Create a copy of Font
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FontCopyWith<_Font> get copyWith => __$FontCopyWithImpl<_Font>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Font&&(identical(other.fontFileName, fontFileName) || other.fontFileName == fontFileName)&&const DeepCollectionEquality().equals(other.fontWghtAxisMap, _fontWghtAxisMap));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fontFileName,const DeepCollectionEquality().hash(_fontWghtAxisMap));
}

@override
String toString() {
    return 'Font(fontFileName: $fontFileName, fontWghtAxisMap: $fontWghtAxisMap)';
}


}

/// @nodoc
abstract mixin class _$FontCopyWith<$Res> implements $FontCopyWith<$Res> {
  factory _$FontCopyWith(_Font value, $Res Function(_Font) _then) = __$FontCopyWithImpl;
@override @useResult
$Res call({
 String fontFileName, Map<String, dynamic> fontWghtAxisMap
});




}
/// @nodoc
class __$FontCopyWithImpl<$Res>
    implements _$FontCopyWith<$Res> {
  __$FontCopyWithImpl(this._self, this._then);

  final _Font _self;
  final $Res Function(_Font) _then;

/// Create a copy of Font
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fontFileName = null,Object? fontWghtAxisMap = null,}) {
  return _then(_Font(
fontFileName: null == fontFileName ? _self.fontFileName : fontFileName // ignore: cast_nullable_to_non_nullable
as String,fontWghtAxisMap: null == fontWghtAxisMap ? _self._fontWghtAxisMap : fontWghtAxisMap // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
