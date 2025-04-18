// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WeatherResponse {

  String? get code;

  String? get updateTime;

  String? get fxLink;

  Now? get now;

  Refer? get refer;

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WeatherResponseCopyWith<WeatherResponse> get copyWith =>
      _$WeatherResponseCopyWithImpl<WeatherResponse>(
          this as WeatherResponse, _$identity);

  /// Serializes this WeatherResponse to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is WeatherResponse &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.fxLink, fxLink) || other.fxLink == fxLink) &&
            (identical(other.now, now) || other.now == now) &&
            (identical(other.refer, refer) || other.refer == refer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, code, updateTime, fxLink, now, refer);

  @override
  String toString() {
    return 'WeatherResponse(code: $code, updateTime: $updateTime, fxLink: $fxLink, now: $now, refer: $refer)';
  }


}

/// @nodoc
abstract mixin class $WeatherResponseCopyWith<$Res> {
  factory $WeatherResponseCopyWith(WeatherResponse value,
      $Res Function(WeatherResponse) _then) = _$WeatherResponseCopyWithImpl;

  @useResult
  $Res call({
    String? code, String? updateTime, String? fxLink, Now? now, Refer? refer
  });


  $NowCopyWith<$Res>? get now;

  $ReferCopyWith<$Res>? get refer;

}

/// @nodoc
class _$WeatherResponseCopyWithImpl<$Res>
    implements $WeatherResponseCopyWith<$Res> {
  _$WeatherResponseCopyWithImpl(this._self, this._then);

  final WeatherResponse _self;
  final $Res Function(WeatherResponse) _then;

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? code = freezed, Object? updateTime = freezed, Object? fxLink = freezed, Object? now = freezed, Object? refer = freezed,}) {
    return _then(_self.copyWith(
      code: freezed == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
      as String?,
      updateTime: freezed == updateTime
          ? _self.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
      as String?,
      fxLink: freezed == fxLink
          ? _self.fxLink
          : fxLink // ignore: cast_nullable_to_non_nullable
      as String?,
      now: freezed == now
          ? _self.now
          : now // ignore: cast_nullable_to_non_nullable
      as Now?,
      refer: freezed == refer
          ? _self.refer
          : refer // ignore: cast_nullable_to_non_nullable
      as Refer?,
    ));
  }

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NowCopyWith<$Res>? get now {
    if (_self.now == null) {
      return null;
    }

    return $NowCopyWith<$Res>(_self.now!, (value) {
      return _then(_self.copyWith(now: value));
    });
  }

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReferCopyWith<$Res>? get refer {
    if (_self.refer == null) {
      return null;
    }

    return $ReferCopyWith<$Res>(_self.refer!, (value) {
      return _then(_self.copyWith(refer: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _WeatherResponse implements WeatherResponse {
  const _WeatherResponse(
      {this.code, this.updateTime, this.fxLink, this.now, this.refer});

  factory _WeatherResponse.fromJson(Map<String, dynamic> json) =>
      _$WeatherResponseFromJson(json);

  @override final String? code;
  @override final String? updateTime;
  @override final String? fxLink;
  @override final Now? now;
  @override final Refer? refer;

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WeatherResponseCopyWith<_WeatherResponse> get copyWith =>
      __$WeatherResponseCopyWithImpl<_WeatherResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WeatherResponseToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _WeatherResponse &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.fxLink, fxLink) || other.fxLink == fxLink) &&
            (identical(other.now, now) || other.now == now) &&
            (identical(other.refer, refer) || other.refer == refer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, code, updateTime, fxLink, now, refer);

  @override
  String toString() {
    return 'WeatherResponse(code: $code, updateTime: $updateTime, fxLink: $fxLink, now: $now, refer: $refer)';
  }


}

/// @nodoc
abstract mixin class _$WeatherResponseCopyWith<$Res>
    implements $WeatherResponseCopyWith<$Res> {
  factory _$WeatherResponseCopyWith(_WeatherResponse value,
      $Res Function(_WeatherResponse) _then) = __$WeatherResponseCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? code, String? updateTime, String? fxLink, Now? now, Refer? refer
  });


  @override $NowCopyWith<$Res>? get now;

  @override $ReferCopyWith<$Res>? get refer;

}

/// @nodoc
class __$WeatherResponseCopyWithImpl<$Res>
    implements _$WeatherResponseCopyWith<$Res> {
  __$WeatherResponseCopyWithImpl(this._self, this._then);

  final _WeatherResponse _self;
  final $Res Function(_WeatherResponse) _then;

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? code = freezed, Object? updateTime = freezed, Object? fxLink = freezed, Object? now = freezed, Object? refer = freezed,}) {
    return _then(_WeatherResponse(
      code: freezed == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
      as String?,
      updateTime: freezed == updateTime
          ? _self.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
      as String?,
      fxLink: freezed == fxLink
          ? _self.fxLink
          : fxLink // ignore: cast_nullable_to_non_nullable
      as String?,
      now: freezed == now
          ? _self.now
          : now // ignore: cast_nullable_to_non_nullable
      as Now?,
      refer: freezed == refer
          ? _self.refer
          : refer // ignore: cast_nullable_to_non_nullable
      as Refer?,
    ));
  }

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NowCopyWith<$Res>? get now {
    if (_self.now == null) {
      return null;
    }

    return $NowCopyWith<$Res>(_self.now!, (value) {
      return _then(_self.copyWith(now: value));
    });
  }

  /// Create a copy of WeatherResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReferCopyWith<$Res>? get refer {
    if (_self.refer == null) {
      return null;
    }

    return $ReferCopyWith<$Res>(_self.refer!, (value) {
      return _then(_self.copyWith(refer: value));
    });
  }
}


/// @nodoc
mixin _$Refer {

  List<String>? get sources;

  List<String>? get license;

  /// Create a copy of Refer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReferCopyWith<Refer> get copyWith =>
      _$ReferCopyWithImpl<Refer>(this as Refer, _$identity);

  /// Serializes this Refer to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Refer &&
            const DeepCollectionEquality().equals(other.sources, sources) &&
            const DeepCollectionEquality().equals(other.license, license));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, const DeepCollectionEquality().hash(sources),
          const DeepCollectionEquality().hash(license));

  @override
  String toString() {
    return 'Refer(sources: $sources, license: $license)';
  }


}

/// @nodoc
abstract mixin class $ReferCopyWith<$Res> {
  factory $ReferCopyWith(Refer value,
      $Res Function(Refer) _then) = _$ReferCopyWithImpl;

  @useResult
  $Res call({
    List<String>? sources, List<String>? license
  });


}

/// @nodoc
class _$ReferCopyWithImpl<$Res>
    implements $ReferCopyWith<$Res> {
  _$ReferCopyWithImpl(this._self, this._then);

  final Refer _self;
  final $Res Function(Refer) _then;

  /// Create a copy of Refer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sources = freezed, Object? license = freezed,}) {
    return _then(_self.copyWith(
      sources: freezed == sources
          ? _self.sources
          : sources // ignore: cast_nullable_to_non_nullable
      as List<String>?,
      license: freezed == license
          ? _self.license
          : license // ignore: cast_nullable_to_non_nullable
      as List<String>?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Refer implements Refer {
  const _Refer({final List<String>? sources, final List<String>? license})
      : _sources = sources,
        _license = license;

  factory _Refer.fromJson(Map<String, dynamic> json) => _$ReferFromJson(json);

  final List<String>? _sources;

  @override List<String>? get sources {
    final value = _sources;
    if (value == null) return null;
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _license;

  @override List<String>? get license {
    final value = _license;
    if (value == null) return null;
    if (_license is EqualUnmodifiableListView) return _license;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }


  /// Create a copy of Refer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReferCopyWith<_Refer> get copyWith =>
      __$ReferCopyWithImpl<_Refer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReferToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Refer &&
            const DeepCollectionEquality().equals(other._sources, _sources) &&
            const DeepCollectionEquality().equals(other._license, _license));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, const DeepCollectionEquality().hash(_sources),
          const DeepCollectionEquality().hash(_license));

  @override
  String toString() {
    return 'Refer(sources: $sources, license: $license)';
  }


}

/// @nodoc
abstract mixin class _$ReferCopyWith<$Res> implements $ReferCopyWith<$Res> {
  factory _$ReferCopyWith(_Refer value,
      $Res Function(_Refer) _then) = __$ReferCopyWithImpl;

  @override
  @useResult
  $Res call({
    List<String>? sources, List<String>? license
  });


}

/// @nodoc
class __$ReferCopyWithImpl<$Res>
    implements _$ReferCopyWith<$Res> {
  __$ReferCopyWithImpl(this._self, this._then);

  final _Refer _self;
  final $Res Function(_Refer) _then;

  /// Create a copy of Refer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? sources = freezed, Object? license = freezed,}) {
    return _then(_Refer(
      sources: freezed == sources
          ? _self._sources
          : sources // ignore: cast_nullable_to_non_nullable
      as List<String>?,
      license: freezed == license
          ? _self._license
          : license // ignore: cast_nullable_to_non_nullable
      as List<String>?,
    ));
  }


}


/// @nodoc
mixin _$Now {

  String? get obsTime;

  String? get temp;

  String? get feelsLike;

  String? get icon;

  String? get text;

  String? get wind360;

  String? get windDir;

  String? get windScale;

  String? get windSpeed;

  String? get humidity;

  String? get precip;

  String? get pressure;

  String? get vis;

  String? get cloud;

  String? get dew;

  /// Create a copy of Now
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NowCopyWith<Now> get copyWith =>
      _$NowCopyWithImpl<Now>(this as Now, _$identity);

  /// Serializes this Now to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Now &&
            (identical(other.obsTime, obsTime) || other.obsTime == obsTime) &&
            (identical(other.temp, temp) || other.temp == temp) &&
            (identical(other.feelsLike, feelsLike) ||
                other.feelsLike == feelsLike) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.wind360, wind360) || other.wind360 == wind360) &&
            (identical(other.windDir, windDir) || other.windDir == windDir) &&
            (identical(other.windScale, windScale) ||
                other.windScale == windScale) &&
            (identical(other.windSpeed, windSpeed) ||
                other.windSpeed == windSpeed) &&
            (identical(other.humidity, humidity) ||
                other.humidity == humidity) &&
            (identical(other.precip, precip) || other.precip == precip) &&
            (identical(other.pressure, pressure) ||
                other.pressure == pressure) &&
            (identical(other.vis, vis) || other.vis == vis) &&
            (identical(other.cloud, cloud) || other.cloud == cloud) &&
            (identical(other.dew, dew) || other.dew == dew));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          obsTime,
          temp,
          feelsLike,
          icon,
          text,
          wind360,
          windDir,
          windScale,
          windSpeed,
          humidity,
          precip,
          pressure,
          vis,
          cloud,
          dew);

  @override
  String toString() {
    return 'Now(obsTime: $obsTime, temp: $temp, feelsLike: $feelsLike, icon: $icon, text: $text, wind360: $wind360, windDir: $windDir, windScale: $windScale, windSpeed: $windSpeed, humidity: $humidity, precip: $precip, pressure: $pressure, vis: $vis, cloud: $cloud, dew: $dew)';
  }


}

/// @nodoc
abstract mixin class $NowCopyWith<$Res> {
  factory $NowCopyWith(Now value, $Res Function(Now) _then) = _$NowCopyWithImpl;

  @useResult
  $Res call({
    String? obsTime, String? temp, String? feelsLike, String? icon, String? text, String? wind360, String? windDir, String? windScale, String? windSpeed, String? humidity, String? precip, String? pressure, String? vis, String? cloud, String? dew
  });


}

/// @nodoc
class _$NowCopyWithImpl<$Res>
    implements $NowCopyWith<$Res> {
  _$NowCopyWithImpl(this._self, this._then);

  final Now _self;
  final $Res Function(Now) _then;

  /// Create a copy of Now
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? obsTime = freezed, Object? temp = freezed, Object? feelsLike = freezed, Object? icon = freezed, Object? text = freezed, Object? wind360 = freezed, Object? windDir = freezed, Object? windScale = freezed, Object? windSpeed = freezed, Object? humidity = freezed, Object? precip = freezed, Object? pressure = freezed, Object? vis = freezed, Object? cloud = freezed, Object? dew = freezed,}) {
    return _then(_self.copyWith(
      obsTime: freezed == obsTime
          ? _self.obsTime
          : obsTime // ignore: cast_nullable_to_non_nullable
      as String?,
      temp: freezed == temp
          ? _self.temp
          : temp // ignore: cast_nullable_to_non_nullable
      as String?,
      feelsLike: freezed == feelsLike
          ? _self.feelsLike
          : feelsLike // ignore: cast_nullable_to_non_nullable
      as String?,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
      as String?,
      text: freezed == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
      as String?,
      wind360: freezed == wind360
          ? _self.wind360
          : wind360 // ignore: cast_nullable_to_non_nullable
      as String?,
      windDir: freezed == windDir
          ? _self.windDir
          : windDir // ignore: cast_nullable_to_non_nullable
      as String?,
      windScale: freezed == windScale
          ? _self.windScale
          : windScale // ignore: cast_nullable_to_non_nullable
      as String?,
      windSpeed: freezed == windSpeed
          ? _self.windSpeed
          : windSpeed // ignore: cast_nullable_to_non_nullable
      as String?,
      humidity: freezed == humidity
          ? _self.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
      as String?,
      precip: freezed == precip
          ? _self.precip
          : precip // ignore: cast_nullable_to_non_nullable
      as String?,
      pressure: freezed == pressure
          ? _self.pressure
          : pressure // ignore: cast_nullable_to_non_nullable
      as String?,
      vis: freezed == vis
          ? _self.vis
          : vis // ignore: cast_nullable_to_non_nullable
      as String?,
      cloud: freezed == cloud
          ? _self.cloud
          : cloud // ignore: cast_nullable_to_non_nullable
      as String?,
      dew: freezed == dew
          ? _self.dew
          : dew // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Now implements Now {
  const _Now(
      {this.obsTime, this.temp, this.feelsLike, this.icon, this.text, this.wind360, this.windDir, this.windScale, this.windSpeed, this.humidity, this.precip, this.pressure, this.vis, this.cloud, this.dew});

  factory _Now.fromJson(Map<String, dynamic> json) => _$NowFromJson(json);

  @override final String? obsTime;
  @override final String? temp;
  @override final String? feelsLike;
  @override final String? icon;
  @override final String? text;
  @override final String? wind360;
  @override final String? windDir;
  @override final String? windScale;
  @override final String? windSpeed;
  @override final String? humidity;
  @override final String? precip;
  @override final String? pressure;
  @override final String? vis;
  @override final String? cloud;
  @override final String? dew;

  /// Create a copy of Now
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NowCopyWith<_Now> get copyWith =>
      __$NowCopyWithImpl<_Now>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NowToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Now &&
            (identical(other.obsTime, obsTime) || other.obsTime == obsTime) &&
            (identical(other.temp, temp) || other.temp == temp) &&
            (identical(other.feelsLike, feelsLike) ||
                other.feelsLike == feelsLike) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.wind360, wind360) || other.wind360 == wind360) &&
            (identical(other.windDir, windDir) || other.windDir == windDir) &&
            (identical(other.windScale, windScale) ||
                other.windScale == windScale) &&
            (identical(other.windSpeed, windSpeed) ||
                other.windSpeed == windSpeed) &&
            (identical(other.humidity, humidity) ||
                other.humidity == humidity) &&
            (identical(other.precip, precip) || other.precip == precip) &&
            (identical(other.pressure, pressure) ||
                other.pressure == pressure) &&
            (identical(other.vis, vis) || other.vis == vis) &&
            (identical(other.cloud, cloud) || other.cloud == cloud) &&
            (identical(other.dew, dew) || other.dew == dew));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          obsTime,
          temp,
          feelsLike,
          icon,
          text,
          wind360,
          windDir,
          windScale,
          windSpeed,
          humidity,
          precip,
          pressure,
          vis,
          cloud,
          dew);

  @override
  String toString() {
    return 'Now(obsTime: $obsTime, temp: $temp, feelsLike: $feelsLike, icon: $icon, text: $text, wind360: $wind360, windDir: $windDir, windScale: $windScale, windSpeed: $windSpeed, humidity: $humidity, precip: $precip, pressure: $pressure, vis: $vis, cloud: $cloud, dew: $dew)';
  }


}

/// @nodoc
abstract mixin class _$NowCopyWith<$Res> implements $NowCopyWith<$Res> {
  factory _$NowCopyWith(_Now value,
      $Res Function(_Now) _then) = __$NowCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? obsTime, String? temp, String? feelsLike, String? icon, String? text, String? wind360, String? windDir, String? windScale, String? windSpeed, String? humidity, String? precip, String? pressure, String? vis, String? cloud, String? dew
  });


}

/// @nodoc
class __$NowCopyWithImpl<$Res>
    implements _$NowCopyWith<$Res> {
  __$NowCopyWithImpl(this._self, this._then);

  final _Now _self;
  final $Res Function(_Now) _then;

  /// Create a copy of Now
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? obsTime = freezed, Object? temp = freezed, Object? feelsLike = freezed, Object? icon = freezed, Object? text = freezed, Object? wind360 = freezed, Object? windDir = freezed, Object? windScale = freezed, Object? windSpeed = freezed, Object? humidity = freezed, Object? precip = freezed, Object? pressure = freezed, Object? vis = freezed, Object? cloud = freezed, Object? dew = freezed,}) {
    return _then(_Now(
      obsTime: freezed == obsTime
          ? _self.obsTime
          : obsTime // ignore: cast_nullable_to_non_nullable
      as String?,
      temp: freezed == temp
          ? _self.temp
          : temp // ignore: cast_nullable_to_non_nullable
      as String?,
      feelsLike: freezed == feelsLike
          ? _self.feelsLike
          : feelsLike // ignore: cast_nullable_to_non_nullable
      as String?,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
      as String?,
      text: freezed == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
      as String?,
      wind360: freezed == wind360
          ? _self.wind360
          : wind360 // ignore: cast_nullable_to_non_nullable
      as String?,
      windDir: freezed == windDir
          ? _self.windDir
          : windDir // ignore: cast_nullable_to_non_nullable
      as String?,
      windScale: freezed == windScale
          ? _self.windScale
          : windScale // ignore: cast_nullable_to_non_nullable
      as String?,
      windSpeed: freezed == windSpeed
          ? _self.windSpeed
          : windSpeed // ignore: cast_nullable_to_non_nullable
      as String?,
      humidity: freezed == humidity
          ? _self.humidity
          : humidity // ignore: cast_nullable_to_non_nullable
      as String?,
      precip: freezed == precip
          ? _self.precip
          : precip // ignore: cast_nullable_to_non_nullable
      as String?,
      pressure: freezed == pressure
          ? _self.pressure
          : pressure // ignore: cast_nullable_to_non_nullable
      as String?,
      vis: freezed == vis
          ? _self.vis
          : vis // ignore: cast_nullable_to_non_nullable
      as String?,
      cloud: freezed == cloud
          ? _self.cloud
          : cloud // ignore: cast_nullable_to_non_nullable
      as String?,
      dew: freezed == dew
          ? _self.dew
          : dew // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }


}

// dart format on
