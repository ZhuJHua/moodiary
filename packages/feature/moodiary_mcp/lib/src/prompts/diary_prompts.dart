/// Prompts of the diary catalog: the instructions a client hands to a model,
/// plus argument completions built from what the database already knows.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';

/// Completions are capped so a picker stays usable.
const int _completionLimit = 20;

const McpPrompt _dailyReview = McpPrompt(
  name: 'daily_review',
  title: 'Review one day',
  description:
      'Asks the model to read the diaries of one day and summarise the mood '
      'and the highlights.',
  arguments: [
    McpPromptArgument(
      name: 'date',
      description: 'Day to review, yyyy-MM-dd. Defaults to today.',
    ),
  ],
);

const McpPrompt _summarizePeriod = McpPrompt(
  name: 'summarize_period',
  title: 'Summarise a period',
  description:
      'Asks the model to read the diaries between two days and summarise the '
      'themes and the mood trend.',
  arguments: [
    McpPromptArgument(
      name: 'start',
      description: 'First day of the period, yyyy-MM-dd.',
      required: true,
    ),
    McpPromptArgument(
      name: 'end',
      description: 'Last day of the period, yyyy-MM-dd.',
      required: true,
    ),
  ],
);

const McpPrompt _findConnections = McpPrompt(
  name: 'find_connections',
  title: 'Find related diaries',
  description:
      'Asks the model to find diaries that are related to one diary through '
      'links, people, places or topics.',
  arguments: [
    McpPromptArgument(
      name: 'diaryId',
      description: 'Id of the diary to look around, as returned by the tools.',
      required: true,
    ),
  ],
);

void registerDiaryPrompts(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
}) {
  final completions = _Completions(categories: categories, insights: insights);

  registry.addPrompt(_dailyReview, (call, arguments) async {
    final day = _dayArgument(
      'daily_review',
      'date',
      arguments['date'],
      fallback: _today(),
    );
    return McpPromptResult(
      description: 'Review of ${_formatDay(day)}',
      messages: [McpPromptMessage.user(_dailyReviewInstructions(day))],
    );
  }, complete: completions.handle);

  registry.addPrompt(_summarizePeriod, (call, arguments) async {
    final start = _dayArgument('summarize_period', 'start', arguments['start']);
    final end = _dayArgument('summarize_period', 'end', arguments['end']);
    if (start.isAfter(end)) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'summarize_period: start must not be after end',
      );
    }
    return McpPromptResult(
      description: 'Summary of ${_formatDay(start)} to ${_formatDay(end)}',
      messages: [
        McpPromptMessage.user(_summarizePeriodInstructions(start, end)),
      ],
    );
  }, complete: completions.handle);

  registry.addPrompt(_findConnections, (call, arguments) async {
    final id = (arguments['diaryId'] ?? '').trim();
    if (id.isEmpty) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'find_connections: diaryId is required',
      );
    }
    final diary = await diaries.getDiaryByBusinessId(id);
    if (diary == null) {
      throw JsonRpcException(
        JsonRpcCode.invalidParams,
        'find_connections: no diary with id="$id"',
      );
    }
    return McpPromptResult(
      description: 'Connections of diary $id',
      messages: [
        McpPromptMessage.user(
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
  final date = _formatDay(day);
  return 'Review my diary entries for $date.\n'
      '\n'
      '1. Call list_diaries with start="$date" and end="$date" to get that '
      "day's entries and their ids.\n"
      '2. Call get_diary for every id with format="markdown"; add '
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
  final from = _formatDay(start);
  final to = _formatDay(end);
  return 'Summarise my diaries from $from to $to.\n'
      '\n'
      '1. Call list_diaries with start="$from", end="$to" and limit=100; page '
      'with offset while hasMore is true, and call get_diary format="markdown" '
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
      : '"${_oneLine(title, 80)}" (id=$id)';
  final written =
      '${_formatDay(time.toLocal())} ${_formatClock(time.toLocal())}';
  return 'Find what connects to my diary $shown, written $written.\n'
      '\n'
      '1. Call get_diary with id="$id" and format="markdown" to read it.\n'
      '2. Call get_diary_links with id="$id" for its forward links and '
      'backlinks.\n'
      '3. Call search_diaries with two or three distinctive phrases from the '
      'body.\n'
      '4. Call list_diaries with start and end around the same weeks to catch '
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
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$prompt: $name is required as yyyy-MM-dd',
    );
  }
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$prompt: $name must be a date in yyyy-MM-dd form',
    );
  }
  final parsed = DateTime.tryParse(text);
  // DateTime.parse normalizes overflow (2026-02-31 becomes March 3), so compare
  // the rendered day back instead of trusting it.
  if (parsed == null || _formatDay(parsed) != text) {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$prompt: $name must be a date in yyyy-MM-dd form',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatDay(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

String _formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _oneLine(String text, [int chars = 80]) =>
    truncate(text.replaceAll(RegExp(r'\s+'), ' ').trim(), chars);

/// Argument completions: days that hold diaries, recent diary ids and category
/// names. Every list is capped at [_completionLimit].
class _Completions {
  _Completions({required this.categories, required this.insights});

  final CategoryRepository categories;
  final MoodInsightsRepository insights;

  Future<McpCompletionResult> handle(
    McpCallContext call,
    String argumentName,
    String partialValue,
  ) async {
    final partial = partialValue.trim().toLowerCase();
    switch (argumentName) {
      case 'date' || 'start' || 'end':
        return _dates(partial);
      case 'diaryId':
        return _diaryIds(partial);
      case 'category' || 'categoryId' || 'categoryName':
        return _categoryNames(partial);
      default:
        return const McpCompletionResult(values: []);
    }
  }

  Future<McpCompletionResult> _dates(String partial) async {
    final entries = await visibleDiaryEntries(insights);
    final values = <String>[];
    final seen = <String>{};
    final today = _formatDay(_today());
    if (today.startsWith(partial) && seen.add(today)) values.add(today);
    for (final entry in entries) {
      if (values.length >= _completionLimit) break;
      final day = _formatDay(entry.time.toLocal());
      if (!day.startsWith(partial) || !seen.add(day)) continue;
      values.add(day);
    }
    return McpCompletionResult(values: values, total: values.length);
  }

  Future<McpCompletionResult> _diaryIds(String partial) async {
    final entries = await visibleDiaryEntries(insights);
    final values = <String>[];
    for (final entry in entries) {
      if (values.length >= _completionLimit) break;
      final matches =
          partial.isEmpty ||
          entry.id.toLowerCase().contains(partial) ||
          entry.title.toLowerCase().contains(partial);
      if (matches) values.add(entry.id);
    }
    return McpCompletionResult(values: values, total: values.length);
  }

  Future<McpCompletionResult> _categoryNames(String partial) async {
    final all = await categories.getAllCategories();
    final values = <String>[
      for (final category in all)
        if (category.categoryName.toLowerCase().startsWith(partial))
          category.categoryName,
    ];
    return McpCompletionResult(
      values: values.take(_completionLimit).toList(),
      total: values.length,
      hasMore: values.length > _completionLimit,
    );
  }
}
