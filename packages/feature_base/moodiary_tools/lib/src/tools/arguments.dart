import 'package:flutter/foundation.dart' show internal;
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_time.dart';
import 'tool_def.dart';
import 'tool_values.dart';

@internal
class ToolArguments {
  ToolArguments(this.subject, this._raw);

  final String subject;

  final Map<String, dynamic> _raw;

  static final RegExp _hexColor = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  static const String _colorArgumentHelp =
      'must be a 32 bit ARGB integer, #RRGGBB or #AARRGGBB; send null or an '
      'empty string to clear the colour';

  bool has(String name) => _raw.containsKey(name);

  bool contains(String name) => _raw[name] != null;

  Never _invalid(String name, String problem) =>
      throw ToolArgumentException('$subject: $name $problem');

  String requireText(String name) {
    final value = _raw[name]! as String;
    final trimmed = value.trim();
    if (trimmed.isEmpty) _invalid(name, 'must not be empty');
    return trimmed;
  }

  String? optionalText(String name) {
    final value = _raw[name] as String?;
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String text(String name) {
    final value = _raw[name]! as String;
    return value.trim();
  }

  bool? optionalBool(String name) => _raw[name] as bool?;

  int optionalInt(String name, ToolIntRange range) =>
      ((_raw[name] as num?)?.toInt() ?? range.fallback).clamp(
        range.min,
        range.max,
      );

  int? optionalColor(String name) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final match = _hexColor.firstMatch(text);
      if (match == null) _invalid(name, _colorArgumentHelp);
      final digits = match.group(1)!;
      final argb = int.parse(digits, radix: 16);
      return digits.length == 6 ? 0xFF000000 | argb : argb;
    }
    return (value as num).toInt();
  }

  List<String>? optionalStringList(String name) {
    final value = _raw[name] as List?;
    if (value == null) return null;
    final out = <String>[];
    for (final item in value) {
      final trimmed = (item as String).trim();
      if (trimmed.isEmpty || out.contains(trimmed)) continue;
      out.add(trimmed);
    }
    return out;
  }

  DiaryMood? optionalMood(String name) => toolMood(_raw[name]);

  DateTime? optionalDate(String name, {bool endOfDay = false}) {
    final text = optionalText(name);
    if (text == null) return null;
    final parsed = resolveDiaryTime(
      text,
      reference: DateTime(2000),
      subject: subject,
      field: name,
    );
    if (endOfDay && text.length == 10) {
      final local = parsed.toLocal();
      return DateTime(
        local.year,
        local.month,
        local.day + 1,
      ).subtract(const Duration(microseconds: 1)).toUtc();
    }
    return parsed;
  }

  void requireOrderedRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && start.isAfter(end)) {
      throw ToolArgumentException(
        '$subject: startDate must not be after endDate',
      );
    }
  }
}
