import 'package:freezed_annotation/freezed_annotation.dart';

import 'place.dart';

part 'place_event.freezed.dart';

@freezed
sealed class PlaceEvent with _$PlaceEvent {
  const factory PlaceEvent.upserted(
    Place place, {
    @Default(false) bool fromSync,
  }) = PlaceUpserted;

  const factory PlaceEvent.deleted(String id, {@Default(false) bool fromSync}) =
      PlaceDeleted;
}
