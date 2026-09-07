import 'dart:convert';

int dbTime(DateTime value) => value.toUtc().microsecondsSinceEpoch;

DateTime dbToTime(int micros) =>
    DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);

int? dbTimeOrNull(DateTime? value) => value == null ? null : dbTime(value);

DateTime? dbToTimeOrNull(int? micros) =>
    micros == null ? null : dbToTime(micros);

String dbStringList(List<String> values) => jsonEncode(values);

List<String> dbToStringList(String json) =>
    (jsonDecode(json) as List).cast<String>();

String? dbStringListOrNull(List<String>? values) =>
    values == null ? null : jsonEncode(values);

List<String>? dbToStringListOrNull(String? json) =>
    json == null ? null : dbToStringList(json);
