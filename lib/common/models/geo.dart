import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo.freezed.dart';
part 'geo.g.dart';

@freezed
abstract class GeoResponse with _$GeoResponse {
  const factory GeoResponse({
    String? code,
    List<Location>? location,
    Refer? refer,
  }) = _GeoResponse;

  factory GeoResponse.fromJson(Map<String, dynamic> json) =>
      _$GeoResponseFromJson(json);
}

@freezed
abstract class Refer with _$Refer {
  const factory Refer({List<String>? sources, List<String>? license}) = _Refer;

  factory Refer.fromJson(Map<String, dynamic> json) => _$ReferFromJson(json);
}

@freezed
abstract class Location with _$Location {
  const factory Location({
    String? name,
    String? id,
    String? lat,
    String? lon,
    String? adm2,
    String? adm1,
    String? country,
    String? tz,
    String? utcOffset,
    String? isDst,
    String? type,
    String? rank,
    String? fxLink,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}
