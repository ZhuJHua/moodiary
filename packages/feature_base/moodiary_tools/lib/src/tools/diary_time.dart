import 'tool_def.dart';

final RegExp _diaryTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?:[Zz]|[+-](\d{2})(?::?(\d{2}))?)?)?$',
);

DateTime resolveDiaryTime(
  Object? value, {
  required DateTime reference,
  required String subject,
}) {
  if (value == null) return reference.toUtc();
  final text = value is String ? value.trim() : '';
  final match = _diaryTimePattern.firstMatch(text);
  if (match == null) {
    throw ToolArgumentException(
      '$subject: time must be an ISO-8601 date or timestamp',
    );
  }
  int part(int index) => int.parse(match.group(index) ?? '0');
  final year = part(1);
  final month = part(2);
  final day = part(3);
  final date = DateTime.utc(year, month, day);
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      part(4) > 23 ||
      part(5) > 59 ||
      part(6) > 59 ||
      part(7) > 23 ||
      part(8) > 59) {
    throw ToolArgumentException(
      '$subject: time must be an ISO-8601 date or timestamp',
    );
  }
  if (match.group(4) == null) {
    final local = reference.toLocal();
    return DateTime(
      year,
      month,
      day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).toUtc();
  }
  return DateTime.parse(text).toUtc();
}
