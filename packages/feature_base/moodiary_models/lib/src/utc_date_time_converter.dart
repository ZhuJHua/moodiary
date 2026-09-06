import 'package:freezed_annotation/freezed_annotation.dart';

class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => .parse(json);

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}
