/// Argument parsing shared by the tool, resource and prompt handlers.
///
/// Every reader throws a [JsonRpcException] with [JsonRpcCode.invalidParams]
/// whose message starts with [Args.subject] and names the offending argument,
/// so a model can repair its call from the message alone. Count-like arguments
/// are clamped to the cap their schema documents instead of failing; a wrong
/// type always fails.
library;

import 'package:moodiary_models/moodiary_models.dart';

import '../protocol/json_rpc.dart';

/// Validating view over the `arguments` object of one MCP call.
class Args {
  Args(this.subject, [Map<String, dynamic>? raw]) : _raw = raw ?? const {};

  /// Surface name used in error messages; usually the tool name.
  final String subject;

  final Map<String, dynamic> _raw;

  static final RegExp _bareDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Media attachment names. No MCP tool writes them: the app only ever adds
  /// media from its editor, so a client that sends these gets told so instead of
  /// silently losing them.
  static const List<String> _mediaArguments = [
    'imageName',
    'audioName',
    'videoName',
    'fileName',
    'media',
  ];

  static const String _moodArgumentHelp =
      'must be one of awful, bad, okay, good, great or a score from 1 to 5';

  /// Whether the client sent the argument at all. An explicit `null` counts as
  /// absent, which is what the `update_*` tools read as "leave this alone";
  /// clearing a field is sent as an empty string instead.
  bool contains(String name) => _raw[name] != null;

  Never _invalid(String name, String problem) => throw JsonRpcException(
    JsonRpcCode.invalidParams,
    '$subject: $name $problem',
  );

  Never _invalidMessage(String message) =>
      throw JsonRpcException(JsonRpcCode.invalidParams, '$subject: $message');

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

  /// Untrimmed string; only valid after [contains] confirmed the argument, so a
  /// blank value can clear a field.
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

  /// 32 bit ARGB colour of a category.
  int? optionalArgb(String name) {
    final value = _raw[name];
    if (value == null) return null;
    final parsed = _asInt(name, value);
    if (parsed < 0 || parsed > 0xFFFFFFFF) {
      _invalid(name, 'must be a 32 bit ARGB integer');
    }
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

  /// `awful|bad|okay|good|great` or a score from 1 to 5; a blank value clears
  /// the mood.
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
      _invalidMessage('start must not be after end');
    }
  }

  /// Refuses media arguments by name instead of dropping them.
  void rejectMediaArguments() {
    for (final name in _mediaArguments) {
      if (contains(name)) {
        _invalid(name, 'is not supported: this tool cannot attach media');
      }
    }
  }
}
