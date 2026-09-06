import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'utc_date_time_converter.dart';

part 'place.freezed.dart';
part 'place.g.dart';

@freezed
abstract class Place with _$Place {
  const factory Place({
    required String id,
    required String name,
    required double latitude,
    required double longitude,

    String? icon,

    @UtcDateTimeConverter() required DateTime lastModified,
  }) = _Place;

  const Place._();

  factory Place.create({
    required String name,
    required double latitude,
    required double longitude,
    String? icon,
  }) => Place(
    id: uuidV7(),
    name: name,
    latitude: latitude,
    longitude: longitude,
    icon: icon,
    lastModified: .timestamp(),
  );

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

  factory Place.forName(
    String name, {
    required double latitude,
    required double longitude,
  }) => Place(
    id: idForName(name),
    name: name,
    latitude: latitude,
    longitude: longitude,
    lastModified: .timestamp(),
  );

  static String idForName(String name) => uuidV5(_nameNamespace, name);

  static const String _nameNamespace = '3f0b6a2e-9c4d-5e1f-8a7b-6c5d4e3f2a1b';

  static String coordinateName(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  static const int matchRadius = 200;
}
