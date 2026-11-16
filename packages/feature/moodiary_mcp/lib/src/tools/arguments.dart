/// Shared argument validation. Missing fields and explicit nulls are distinct;
/// count-like arguments are clamped, while wrong types fail.
library;

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// Validating view over the `arguments` object of one MCP call.
class Args {
  Args(this.subject, [Map<String, dynamic>? raw]) : _raw = raw ?? const {};

  /// Surface name used in error messages; usually the tool name.
  final String subject;

  final Map<String, dynamic> _raw;

  static final RegExp _bareDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// `#RRGGBB` or `#AARRGGBB`, the two colour strings a client may send.
  static final RegExp _hexColor = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  static const String _moodArgumentHelp =
      'must be one of awful, bad, okay, good, great or a score from 1 to 5';

  static const String _colorArgumentHelp =
      'must be a 32 bit ARGB integer, #RRGGBB or #AARRGGBB; send null or an '
      'empty string to clear the colour';

  /// True for explicit null, allowing nullable fields to be cleared.
  bool has(String name) => _raw.containsKey(name);

  /// False for missing or null fields, leaving non-nullable fields unchanged.
  bool contains(String name) => _raw[name] != null;

  Never _invalid(String name, String problem) =>
      throw McpError(ErrorCode.invalidParams.value, '$subject: $name $problem');

  Never _invalidMessage(String message) =>
      throw McpError(ErrorCode.invalidParams.value, '$subject: $message');

  /// Required, trimmed, non-empty string.
  String requireText(String name) {
    final value = _raw[name];
    if (value == null) _invalid(name, 'is required');
    if (value is! String) _invalid(name, 'must be a string');
    final trimmed = value.trim();
    if (trimmed.isEmpty) _invalid(name, 'must not be empty');
    return trimmed;
  }

  /// Trimmed string, or `null` when absent or blank.
  String? optionalText(String name) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is! String) _invalid(name, 'must be a string');
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Trimmed string; only valid after [contains] confirmed the argument, so a
  /// blank value can clear a field while an absent one stays untouched.
  String text(String name) {
    final value = _raw[name];
    if (value is! String) _invalid(name, 'must be a string');
    return value.trim();
  }

  bool? optionalBool(String name) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is! bool) _invalid(name, 'must be a boolean');
    return value;
  }

  /// Integer argument clamped into `[min, max]`.
  int optionalInt(
    String name, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final value = _raw[name];
    if (value == null) return fallback;
    final parsed = _asInt(name, value);
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  /// Accepts an ARGB integer, `#RRGGBB` or `#AARRGGBB`. Null and blank clear
  /// the colour; use [has] to distinguish clearing from an absent field.
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
    final parsed = switch (value) {
      final int intValue => intValue,
      final double doubleValue
          when doubleValue.isFinite &&
              doubleValue == doubleValue.roundToDouble() =>
        doubleValue.toInt(),
      _ => _invalid(name, _colorArgumentHelp),
    };
    if (parsed < 0 || parsed > 0xFFFFFFFF) _invalid(name, _colorArgumentHelp);
    return parsed;
  }

  int _asInt(String name, Object value) {
    if (value is int) return value;
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    _invalid(name, 'must be an integer');
  }

  /// One of [allowed].
  String? optionalEnum(String name, List<String> allowed) {
    final value = optionalText(name);
    if (value == null) return null;
    if (!allowed.contains(value)) {
      _invalid(name, 'must be one of ${allowed.join(', ')}');
    }
    return value;
  }

  /// Trimmed, deduplicated, blank-free string list.
  List<String>? optionalStringList(String name, {int maxItems = 100}) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is! List) _invalid(name, 'must be an array of strings');
    final out = <String>[];
    for (final item in value) {
      if (item is! String) _invalid(name, 'must be an array of strings');
      final trimmed = item.trim();
      if (trimmed.isEmpty || out.contains(trimmed)) continue;
      if (out.length == maxItems) break;
      out.add(trimmed);
    }
    return out;
  }

  /// `awful|bad|okay|good|great` or a score from 1 to 5; a blank value or an
  /// explicit `null` clears the mood.
  DiaryMood? optionalMood(String name) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is int) return _moodByScore(name, value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final byName = DiaryMood.fromName(text.toLowerCase());
      if (byName != null) return byName;
      final score = int.tryParse(text);
      if (score != null) return _moodByScore(name, score);
    }
    _invalid(name, _moodArgumentHelp);
  }

  DiaryMood _moodByScore(String name, int score) {
    final mood = DiaryMood.fromScore(score);
    if (mood == null) _invalid(name, _moodArgumentHelp);
    return mood;
  }

  /// ISO-8601 instant, always returned in UTC because that is how the database
  /// stores time. A bare `yyyy-MM-dd` means local midnight; with [endOfDay] it
  /// means the last instant of that local day, so a date-only upper bound still
  /// covers the whole day.
  DateTime? optionalDate(String name, {bool endOfDay = false}) {
    final text = optionalText(name);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      _invalid(name, 'must be an ISO-8601 date or timestamp');
    }
    if (endOfDay && _bareDate.hasMatch(text)) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day + 1,
      ).subtract(const Duration(microseconds: 1)).toUtc();
    }
    return parsed.toUtc();
  }

  /// Fails when [start] and [end] are both present and reversed.
  void requireOrderedRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && start.isAfter(end)) {
      _invalidMessage('startDate must not be after endDate');
    }
  }
}

/// Args owns validation and normalization, including clamped numeric inputs.
class ToolArgumentSchema extends ToolInputSchema {
  const ToolArgumentSchema(this.schema);

  final Map<String, dynamic> schema;

  @override
  Map<String, dynamic> toJson() => schema;

  @override
  Object toJsonValue() => const {'type': 'object'};
}
