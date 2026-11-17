/// Prompts of the diary catalog: the instructions a client hands to a model,
/// plus argument completions built from what the database already knows.
library;

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../tools/mcp_results.dart';

/// Completions are capped so a picker stays usable.
const int _completionLimit = 20;
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

const Prompt _dailyReview = Prompt(
  name: 'daily_review',
  title: 'Review one day',
  description:
      'Asks the model to read the diaries of one day and summarise the mood '
      'and the highlights.',
  arguments: [
    PromptArgument(
      name: 'date',
      description: 'Day to review, yyyy-MM-dd. Defaults to today.',
    ),
  ],
);

const Prompt _summarizePeriod = Prompt(
  name: 'summarize_period',
  title: 'Summarise a period',
  description:
      'Asks the model to read the diaries between two days and summarise the '
      'themes and the mood trend.',
  arguments: [
    PromptArgument(
      name: 'start',
      description: 'First day of the period, yyyy-MM-dd.',
      required: true,
    ),
    PromptArgument(
      name: 'end',
      description: 'Last day of the period, yyyy-MM-dd.',
      required: true,
    ),
  ],
);

const Prompt _findConnections = Prompt(
  name: 'find_connections',
  title: 'Find related diaries',
  description:
      'Asks the model to find diaries that are related to one diary through '
      'links, people, places or topics.',
  arguments: [
    PromptArgument(
      name: 'diaryId',
      description: 'Id of the diary to look around, as returned by the tools.',
      required: true,
    ),
  ],
);

void registerDiaryPrompts(
  McpServer server, {
  required DiaryRepository diaries,
  required MoodInsightsRepository insights,
}) {
  final completions = _Completions(insights: insights);

  registerPrompt(server, _dailyReview, (arguments, call) async {
    final day = _dayArgument(
      'daily_review',
      'date',
      arguments['date'],
      fallback: _today(),
    );
    return GetPromptResult(
      description: 'Review of ${TimeFormat.isoDate(day)}',
      messages: [userPromptMessage(_dailyReviewInstructions(day))],
    );
  }, complete: completions.handle);

  registerPrompt(server, _summarizePeriod, (arguments, call) async {
    final start = _dayArgument('summarize_period', 'start', arguments['start']);
    final end = _dayArgument('summarize_period', 'end', arguments['end']);
    if (start.isAfter(end)) {
      throw McpError(
        ErrorCode.invalidParams.value,
        'summarize_period: start must not be after end',
      );
    }
    return GetPromptResult(
      description:
          'Summary of ${TimeFormat.isoDate(start)} to ${TimeFormat.isoDate(end)}',
      messages: [userPromptMessage(_summarizePeriodInstructions(start, end))],
    );
  }, complete: completions.handle);

  registerPrompt(server, _findConnections, (arguments, call) async {
    final id = (arguments['diaryId'] ?? '').trim();
    if (id.isEmpty) {
      throw McpError(
        ErrorCode.invalidParams.value,
        'find_connections: diaryId is required',
      );
    }
    final diary = await diaries.getDiaryByBusinessId(id);
    if (diary == null) {
      throw McpError(
        ErrorCode.invalidParams.value,
        'find_connections: no diary with id="$id"',
      );
    }
    return GetPromptResult(
      description: 'Connections of diary $id',
      messages: [
        userPromptMessage(
          _findConnectionsInstructions(
            id: diary.id,
            title: diary.title,
            time: diary.time,
          ),
        ),
      ],
    );
  }, complete: completions.handle);
}

String _dailyReviewInstructions(DateTime day) {
  final date = TimeFormat.isoDate(day);
  return 'Review my diary entries for $date.\n'
      '\n'
      '1. Call search_diaries with startDate="$date" and endDate="$date" to get that '
      "day's entries and their ids.\n"
      '2. Call get_diary with ids (at most 10) and contentFormat="markdown"; add '
      'get_diary_links when an entry mentions another diary.\n'
      '3. Summarise the day: the overall mood, two or three highlights, what I '
      'wrote about people, plans or worries, and one detail I might have '
      'overlooked.\n'
      '\n'
      'Use only what the tools return and quote sparingly. If $date has no '
      'diary, say so and offer to write one with create_diary instead of '
      'inventing an entry.';
}

String _summarizePeriodInstructions(DateTime start, DateTime end) {
  final from = TimeFormat.isoDate(start);
  final to = TimeFormat.isoDate(end);
  return 'Summarise my diaries from $from to $to.\n'
      '\n'
      '1. Call search_diaries with startDate="$from", endDate="$to" and limit=100; page '
      'with offset while hasMore is true, and call get_diary with ids (at most 10) and contentFormat="markdown" '
      'for the entries you quote.\n'
      '2. Call search_diaries for anything that looks recurring, and '
      'get_stats if the mood trend matters.\n'
      '3. Report the mood trend, the recurring people, places and themes, the '
      'small wins and the questions I return to. Group by theme rather than by '
      'day, and cite diary ids and dates.\n'
      '\n'
      'If the period has no diaries, say so and stop.';
}

String _findConnectionsInstructions({
  required String id,
  required String title,
  required DateTime time,
}) {
  final shown = title.trim().isEmpty
      ? 'the untitled diary $id'
      : '"${_oneLine(title)}" (id=$id)';
  final written =
      '${TimeFormat.isoDate(time.toLocal())} ${_formatClock(time.toLocal())}';
  return 'Find what connects to my diary $shown, written $written.\n'
      '\n'
      '1. Call get_diary with ids=["$id"] and contentFormat="markdown" to read it.\n'
      '2. Call get_diary_links with id="$id" for its forward links and '
      'backlinks.\n'
      '3. Call search_diaries with two or three distinctive phrases from the '
      'body.\n'
      '4. Call search_diaries with startDate and endDate around the same weeks to catch '
      'entries the search misses.\n'
      '\n'
      'Report the related diaries with their ids, dates and the reason you '
      'link them (shared person, place, topic or mood). Mark clearly what the '
      'tools showed and what is your guess, and do not invent a connection.';
}

/// A `yyyy-MM-dd` prompt argument as a local calendar day.
DateTime _dayArgument(
  String prompt,
  String name,
  String? raw, {
  DateTime? fallback,
}) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) {
    if (fallback != null) return fallback;
    throw McpError(
      ErrorCode.invalidParams.value,
      '$prompt: $name is required as yyyy-MM-dd',
    );
  }
  if (!_datePattern.hasMatch(text)) {
    throw McpError(
      ErrorCode.invalidParams.value,
      '$prompt: $name must be a date in yyyy-MM-dd form',
    );
  }
  final parsed = DateTime.tryParse(text);
  // DateTime.parse normalizes overflow (2026-02-31 becomes March 3), so compare
  // the rendered day back instead of trusting it.
  if (parsed == null || TimeFormat.isoDate(parsed) != text) {
    throw McpError(
      ErrorCode.invalidParams.value,
      '$prompt: $name must be a date in yyyy-MM-dd form',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// `yyyy-MM-dd` of a local day: Dart's ISO-8601 output for a local instant
/// starts with exactly that and zero-pads it the same way.
/// `HH:mm` of a local instant, at offset 11 of the same ISO form.
String _formatClock(DateTime time) => time.toIso8601String().substring(11, 16);

String _oneLine(String text, [int chars = 80]) =>
    truncate(text.replaceAll(_whitespace, ' ').trim(), chars);

/// Argument completions: the days that hold diaries and the recent diary ids,
/// the only argument shapes the three prompts take. Every list is capped at
/// [_completionLimit].
class _Completions {
  _Completions({required this.insights});

  final MoodInsightsRepository insights;

  Future<List<String>> handle(String argumentName, String partialValue) async {
    final partial = partialValue.trim().toLowerCase();
    switch (argumentName) {
      case 'date' || 'start' || 'end':
        return _dates(partial);
      case 'diaryId':
        return _diaryIds(partial);
      default:
        return const [];
    }
  }

  Future<List<String>> _dates(String partial) async {
    final entries = await insights.allVisibleEntries();
    final values = <String>[];
    final seen = <String>{};
    final today = TimeFormat.isoDate(_today());
    if (today.startsWith(partial) && seen.add(today)) values.add(today);
    for (final entry in entries) {
      if (values.length >= _completionLimit) break;
      final day = TimeFormat.isoDate(entry.time.toLocal());
      if (!day.startsWith(partial) || !seen.add(day)) continue;
      values.add(day);
    }
    return values;
  }

  Future<List<String>> _diaryIds(String partial) async {
    final entries = await insights.allVisibleEntries();
    final values = <String>[];
    for (final entry in entries) {
      if (values.length >= _completionLimit) break;
      final matches =
          partial.isEmpty ||
          entry.id.toLowerCase().contains(partial) ||
          entry.title.toLowerCase().contains(partial);
      if (matches) values.add(entry.id);
    }
    return values;
  }
}
