import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'utc_date_time_converter.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

@freezed
abstract class Tag with _$Tag {
  const factory Tag({
    required String id,
    required String name,
    @Default(false) bool deleted,
    @UtcDateTimeConverter() required DateTime lastModified,
  }) = _Tag;

  const Tag._();

  factory Tag.create(String name) =>
      Tag(id: uuidV7(), name: name, lastModified: .timestamp());

  factory Tag.legacy(String name) => Tag(
    id: legacyId(name),
    name: name,
    lastModified: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  static String legacyId(String normalizedName) =>
      uuidV5('ce6729c4-5ca5-446a-9892-bb26153ac802', normalizedName);

  static String? normalize(String raw) {
    final name = raw.trim().replaceFirst(RegExp(r'^[#\s]+'), '');
    return name.isEmpty ? null : name.replaceAll(RegExp(r'\s+'), ' ');
  }
}
