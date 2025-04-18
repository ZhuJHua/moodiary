// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeoResponse {

  String? get code;

  List<Location>? get location;

  Refer? get refer;

  /// Create a copy of GeoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GeoResponseCopyWith<GeoResponse> get copyWith =>
      _$GeoResponseCopyWithImpl<GeoResponse>(this as GeoResponse, _$identity);

  /// Serializes this GeoResponse to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is GeoResponse &&
            (identical(other.code, code) || other.code == code) &&
            const DeepCollectionEquality().equals(other.location, location) &&
            (identical(other.refer, refer) || other.refer == refer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
      runtimeType, code, const DeepCollectionEquality().hash(location), refer);

  @override
  String toString() {
    return 'GeoResponse(code: $code, location: $location, refer: $refer)';
  }


}

/// @nodoc
abstract mixin class $GeoResponseCopyWith<$Res> {
  factory $GeoResponseCopyWith(GeoResponse value,
      $Res Function(GeoResponse) _then) = _$GeoResponseCopyWithImpl;

  @useResult
  $Res call({
    String? code, List<Location>? location, Refer? refer
  });


  $ReferCopyWith<$Res>? get refer;

}

/// @nodoc
class _$GeoResponseCopyWithImpl<$Res>
    implements $GeoResponseCopyWith<$Res> {
  _$GeoResponseCopyWithImpl(this._self, this._then);

  final GeoResponse _self;
  final $Res Function(GeoResponse) _then;

  /// Create a copy of GeoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? code = freezed, Object? location = freezed, Object? refer = freezed,}) {
    return _then(_self.copyWith(
      code: freezed == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
      as String?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
      as List<Location>?,
      refer: freezed == refer
          ? _self.refer
          : refer // ignore: cast_nullable_to_non_nullable
      as Refer?,
    ));
  }

  /// Create a copy of GeoResponse
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
class _GeoResponse implements GeoResponse {
  const _GeoResponse({this.code, final List<Location>? location, this.refer})
      : _location = location;

  factory _GeoResponse.fromJson(Map<String, dynamic> json) =>
      _$GeoResponseFromJson(json);

  @override final String? code;
  final List<Location>? _location;

  @override List<Location>? get location {
    final value = _location;
    if (value == null) return null;
    if (_location is EqualUnmodifiableListView) return _location;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override final Refer? refer;

  /// Create a copy of GeoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GeoResponseCopyWith<_GeoResponse> get copyWith =>
      __$GeoResponseCopyWithImpl<_GeoResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GeoResponseToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _GeoResponse &&
            (identical(other.code, code) || other.code == code) &&
            const DeepCollectionEquality().equals(other._location, _location) &&
            (identical(other.refer, refer) || other.refer == refer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
      runtimeType, code, const DeepCollectionEquality().hash(_location), refer);

  @override
  String toString() {
    return 'GeoResponse(code: $code, location: $location, refer: $refer)';
  }


}

/// @nodoc
abstract mixin class _$GeoResponseCopyWith<$Res>
    implements $GeoResponseCopyWith<$Res> {
  factory _$GeoResponseCopyWith(_GeoResponse value,
      $Res Function(_GeoResponse) _then) = __$GeoResponseCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? code, List<Location>? location, Refer? refer
  });


  @override $ReferCopyWith<$Res>? get refer;

}

/// @nodoc
class __$GeoResponseCopyWithImpl<$Res>
    implements _$GeoResponseCopyWith<$Res> {
  __$GeoResponseCopyWithImpl(this._self, this._then);

  final _GeoResponse _self;
  final $Res Function(_GeoResponse) _then;

  /// Create a copy of GeoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? code = freezed, Object? location = freezed, Object? refer = freezed,}) {
    return _then(_GeoResponse(
      code: freezed == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
      as String?,
      location: freezed == location
          ? _self._location
          : location // ignore: cast_nullable_to_non_nullable
      as List<Location>?,
      refer: freezed == refer
          ? _self.refer
          : refer // ignore: cast_nullable_to_non_nullable
      as Refer?,
    ));
  }

  /// Create a copy of GeoResponse
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
mixin _$Location {

  String? get name;

  String? get id;

  String? get lat;

  String? get lon;

  String? get adm2;

  String? get adm1;

  String? get country;

  String? get tz;

  String? get utcOffset;

  String? get isDst;

  String? get type;

  String? get rank;

  String? get fxLink;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LocationCopyWith<Location> get copyWith =>
      _$LocationCopyWithImpl<Location>(this as Location, _$identity);

  /// Serializes this Location to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Location &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lon, lon) || other.lon == lon) &&
            (identical(other.adm2, adm2) || other.adm2 == adm2) &&
            (identical(other.adm1, adm1) || other.adm1 == adm1) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.tz, tz) || other.tz == tz) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.isDst, isDst) || other.isDst == isDst) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.fxLink, fxLink) || other.fxLink == fxLink));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          name,
          id,
          lat,
          lon,
          adm2,
          adm1,
          country,
          tz,
          utcOffset,
          isDst,
          type,
          rank,
          fxLink);

  @override
  String toString() {
    return 'Location(name: $name, id: $id, lat: $lat, lon: $lon, adm2: $adm2, adm1: $adm1, country: $country, tz: $tz, utcOffset: $utcOffset, isDst: $isDst, type: $type, rank: $rank, fxLink: $fxLink)';
  }


}

/// @nodoc
abstract mixin class $LocationCopyWith<$Res> {
  factory $LocationCopyWith(Location value,
      $Res Function(Location) _then) = _$LocationCopyWithImpl;

  @useResult
  $Res call({
    String? name, String? id, String? lat, String? lon, String? adm2, String? adm1, String? country, String? tz, String? utcOffset, String? isDst, String? type, String? rank, String? fxLink
  });


}

/// @nodoc
class _$LocationCopyWithImpl<$Res>
    implements $LocationCopyWith<$Res> {
  _$LocationCopyWithImpl(this._self, this._then);

  final Location _self;
  final $Res Function(Location) _then;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? name = freezed, Object? id = freezed, Object? lat = freezed, Object? lon = freezed, Object? adm2 = freezed, Object? adm1 = freezed, Object? country = freezed, Object? tz = freezed, Object? utcOffset = freezed, Object? isDst = freezed, Object? type = freezed, Object? rank = freezed, Object? fxLink = freezed,}) {
    return _then(_self.copyWith(
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as String?,
      lat: freezed == lat
          ? _self.lat
          : lat // ignore: cast_nullable_to_non_nullable
      as String?,
      lon: freezed == lon
          ? _self.lon
          : lon // ignore: cast_nullable_to_non_nullable
      as String?,
      adm2: freezed == adm2
          ? _self.adm2
          : adm2 // ignore: cast_nullable_to_non_nullable
      as String?,
      adm1: freezed == adm1
          ? _self.adm1
          : adm1 // ignore: cast_nullable_to_non_nullable
      as String?,
      country: freezed == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
      as String?,
      tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
      as String?,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
      as String?,
      isDst: freezed == isDst
          ? _self.isDst
          : isDst // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      rank: freezed == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
      as String?,
      fxLink: freezed == fxLink
          ? _self.fxLink
          : fxLink // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Location implements Location {
  const _Location(
      {this.name, this.id, this.lat, this.lon, this.adm2, this.adm1, this.country, this.tz, this.utcOffset, this.isDst, this.type, this.rank, this.fxLink});

  factory _Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  @override final String? name;
  @override final String? id;
  @override final String? lat;
  @override final String? lon;
  @override final String? adm2;
  @override final String? adm1;
  @override final String? country;
  @override final String? tz;
  @override final String? utcOffset;
  @override final String? isDst;
  @override final String? type;
  @override final String? rank;
  @override final String? fxLink;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LocationCopyWith<_Location> get copyWith =>
      __$LocationCopyWithImpl<_Location>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LocationToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Location &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lon, lon) || other.lon == lon) &&
            (identical(other.adm2, adm2) || other.adm2 == adm2) &&
            (identical(other.adm1, adm1) || other.adm1 == adm1) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.tz, tz) || other.tz == tz) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.isDst, isDst) || other.isDst == isDst) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.fxLink, fxLink) || other.fxLink == fxLink));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          name,
          id,
          lat,
          lon,
          adm2,
          adm1,
          country,
          tz,
          utcOffset,
          isDst,
          type,
          rank,
          fxLink);

  @override
  String toString() {
    return 'Location(name: $name, id: $id, lat: $lat, lon: $lon, adm2: $adm2, adm1: $adm1, country: $country, tz: $tz, utcOffset: $utcOffset, isDst: $isDst, type: $type, rank: $rank, fxLink: $fxLink)';
  }


}

/// @nodoc
abstract mixin class _$LocationCopyWith<$Res>
    implements $LocationCopyWith<$Res> {
  factory _$LocationCopyWith(_Location value,
      $Res Function(_Location) _then) = __$LocationCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? name, String? id, String? lat, String? lon, String? adm2, String? adm1, String? country, String? tz, String? utcOffset, String? isDst, String? type, String? rank, String? fxLink
  });


}

/// @nodoc
class __$LocationCopyWithImpl<$Res>
    implements _$LocationCopyWith<$Res> {
  __$LocationCopyWithImpl(this._self, this._then);

  final _Location _self;
  final $Res Function(_Location) _then;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? name = freezed, Object? id = freezed, Object? lat = freezed, Object? lon = freezed, Object? adm2 = freezed, Object? adm1 = freezed, Object? country = freezed, Object? tz = freezed, Object? utcOffset = freezed, Object? isDst = freezed, Object? type = freezed, Object? rank = freezed, Object? fxLink = freezed,}) {
    return _then(_Location(
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as String?,
      lat: freezed == lat
          ? _self.lat
          : lat // ignore: cast_nullable_to_non_nullable
      as String?,
      lon: freezed == lon
          ? _self.lon
          : lon // ignore: cast_nullable_to_non_nullable
      as String?,
      adm2: freezed == adm2
          ? _self.adm2
          : adm2 // ignore: cast_nullable_to_non_nullable
      as String?,
      adm1: freezed == adm1
          ? _self.adm1
          : adm1 // ignore: cast_nullable_to_non_nullable
      as String?,
      country: freezed == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
      as String?,
      tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
      as String?,
      utcOffset: freezed == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
      as String?,
      isDst: freezed == isDst
          ? _self.isDst
          : isDst // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      rank: freezed == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
      as String?,
      fxLink: freezed == fxLink
          ? _self.fxLink
          : fxLink // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }


}

// dart format on
