// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

 ThemeData get lightTheme; ThemeData get darkTheme; ThemeMode get themeMode; Locale get locale;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.lightTheme, lightTheme) || other.lightTheme == lightTheme)&&(identical(other.darkTheme, darkTheme) || other.darkTheme == darkTheme)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.locale, locale) || other.locale == locale));
}


@override
int get hashCode => Object.hash(runtimeType,lightTheme,darkTheme,themeMode,locale);

@override
String toString() {
  return 'AppSettings(lightTheme: $lightTheme, darkTheme: $darkTheme, themeMode: $themeMode, locale: $locale)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 ThemeData lightTheme, ThemeData darkTheme, ThemeMode themeMode, Locale locale
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lightTheme = null,Object? darkTheme = null,Object? themeMode = null,Object? locale = null,}) {
  return _then(AppSettings(
lightTheme: null == lightTheme ? _self.lightTheme : lightTheme // ignore: cast_nullable_to_non_nullable
as ThemeData,darkTheme: null == darkTheme ? _self.darkTheme : darkTheme // ignore: cast_nullable_to_non_nullable
as ThemeData,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as Locale,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemeData lightTheme,  ThemeData darkTheme,  ThemeMode themeMode,  Locale locale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.lightTheme,_that.darkTheme,_that.themeMode,_that.locale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemeData lightTheme,  ThemeData darkTheme,  ThemeMode themeMode,  Locale locale)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.lightTheme,_that.darkTheme,_that.themeMode,_that.locale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemeData lightTheme,  ThemeData darkTheme,  ThemeMode themeMode,  Locale locale)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.lightTheme,_that.darkTheme,_that.themeMode,_that.locale);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings implements AppSettings {
  const _AppSettings({required this.lightTheme, required this.darkTheme, required this.themeMode, required this.locale});
  

@override final  ThemeData lightTheme;
@override final  ThemeData darkTheme;
@override final  ThemeMode themeMode;
@override final  Locale locale;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.lightTheme, lightTheme) || other.lightTheme == lightTheme)&&(identical(other.darkTheme, darkTheme) || other.darkTheme == darkTheme)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.locale, locale) || other.locale == locale));
}


@override
int get hashCode => Object.hash(runtimeType,lightTheme,darkTheme,themeMode,locale);

@override
String toString() {
  return 'AppSettings(lightTheme: $lightTheme, darkTheme: $darkTheme, themeMode: $themeMode, locale: $locale)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 ThemeData lightTheme, ThemeData darkTheme, ThemeMode themeMode, Locale locale
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lightTheme = null,Object? darkTheme = null,Object? themeMode = null,Object? locale = null,}) {
  return _then(_AppSettings(
lightTheme: null == lightTheme ? _self.lightTheme : lightTheme // ignore: cast_nullable_to_non_nullable
as ThemeData,darkTheme: null == darkTheme ? _self.darkTheme : darkTheme // ignore: cast_nullable_to_non_nullable
as ThemeData,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as Locale,
  ));
}


}

// dart format on
