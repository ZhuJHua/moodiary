import 'dart:convert';

/// `DateTime` → 库内 INTEGER（UTC 微秒）。
int dbTime(DateTime value) => value.toUtc().microsecondsSinceEpoch;

/// 库内 INTEGER → UTC `DateTime`（绝对时刻；UI 展示前照旧 `toLocal()`）。
DateTime dbToTime(int micros) =>
    DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);

int? dbTimeOrNull(DateTime? value) => value == null ? null : dbTime(value);

DateTime? dbToTimeOrNull(int? micros) =>
    micros == null ? null : dbToTime(micros);

/// JSON 文本列 ↔ 字符串列表。`NULL` 与 `'[]'` 语义不同（如 toolsSnapshot 的
/// 「不限」vs「全不挂」），可空性由调用方自己分派。
String dbStringList(List<String> values) => jsonEncode(values);

List<String> dbToStringList(String json) =>
    (jsonDecode(json) as List).cast<String>();

String? dbStringListOrNull(List<String>? values) =>
    values == null ? null : jsonEncode(values);

List<String>? dbToStringListOrNull(String? json) =>
    json == null ? null : dbToStringList(json);
