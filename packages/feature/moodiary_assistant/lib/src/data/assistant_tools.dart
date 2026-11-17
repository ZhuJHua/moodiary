import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import 'assistant_defs.dart';
import 'assistant_tool_definitions.dart';
import 'tool_call_data.dart';

class AssistantToolSpec {
  AssistantToolSpec(this.definition)
    : tool = AssistantTool.values.firstWhere(
        (tool) => tool.id == definition.name,
      );
  final ToolDef definition;
  String get id => definition.name;
  final AssistantTool tool;
  String get description => definition.description(ToolSurface.assistant);
  Map<String, dynamic> get jsonSchema =>
      definition.input(ToolSurface.assistant).value;
  bool get replayResult => tool == AssistantTool.recallMemory;
  Future<String> run(Map<String, dynamic> input) async =>
      jsonEncode((await definition.call(input, assistantToolContext())).data);

  @visibleForTesting
  String summaryOf(Map<String, dynamic> input, String output) =>
      _summary(input, output, decodeJsonMap(output));

  String _summary(
    Map<String, dynamic> input,
    String output,
    Map<String, dynamic>? data,
  ) {
    if (output.startsWith('Failed:')) return l10n.assistant.toolFailed;
    if (output.startsWith(assistantToolSkippedPrefix)) {
      return l10n.assistant.toolSkipped;
    }
    if (data != null) return _jsonSummary(data, input);
    return switch (tool) {
      .searchDiaries => AssistantToolRegistry._summarizeQuery(input, output),
      .getDiary => AssistantToolRegistry._summarizeGet(input),
      .getStats => AssistantToolRegistry._summarizeStats(output),
      .listCategories ||
      .recallMemory => AssistantToolRegistry._summarizeList(output),
      .deleteDiary => AssistantToolRegistry._summarizeDelete(input),
      .runJavascript => AssistantToolRegistry._summarizeJavascript(output),
      _ => AssistantToolRegistry._summarizeWrite(tool, input),
    };
  }

  String _jsonSummary(Map<String, dynamic> data, Map<String, dynamic> input) {
    final results = (data['results'] as List?)?.cast<Map>();
    if (results != null) {
      final succeeded = results.where((row) => row['ok'] == true).toList();
      final failed = results.length - succeeded.length;
      if (failed > 0) {
        return l10n.assistant.toolBatchOutcome(
          succeeded: succeeded.length,
          failed: failed,
        );
      }
      if (succeeded.isEmpty) return l10n.assistant.toolNoMatch;
      final row = succeeded.first;
      final item = switch (tool) {
        .createDiary || .updateDiary => row['diary'] as Map? ?? const {},
        .createCategory ||
        .updateCategory => row['category'] as Map? ?? const {},
        _ => row,
      };
      return AssistantToolRegistry._writeSummary(tool, succeeded.length, item);
    }
    final int count = switch (tool) {
      .searchDiaries => data['total'] as int? ?? 0,
      .getDiary => (data['diaries'] as List?)?.length ?? 0,
      .getStats => data['visibleDiaries'] as int? ?? 0,
      .listCategories => (data['categories'] as List?)?.length ?? 0,
      .listTags => (data['tags'] as List?)?.length ?? 0,
      .getDiaryLinks =>
        ((data['forward'] as List?)?.length ?? 0) +
            ((data['backlinks'] as List?)?.length ?? 0),
      .recallMemory => (data['facts'] as List?)?.length ?? 0,
      _ => 0,
    };
    if (tool == AssistantTool.runJavascript) {
      return AssistantToolRegistry._trimToNull(data['value']) ??
          l10n.assistant.toolJsEmpty;
    }
    if (tool == AssistantTool.getDiary) {
      return l10n.assistant.toolRead(count: count);
    }
    if (tool == AssistantTool.searchDiaries) {
      return AssistantToolRegistry._querySummary(count, input);
    }
    if (tool == AssistantTool.getStats) {
      return l10n.assistant.toolMatched(count: count);
    }
    return count == 0
        ? l10n.assistant.toolNoMatch
        : l10n.assistant.toolListed(count: count);
  }
}

abstract final class AssistantToolRegistry {
  static final List<AssistantToolSpec> specs = [
    for (final def in assistantToolDefinitions) AssistantToolSpec(def),
  ];
  static final _byId = {for (final spec in specs) spec.id: spec};
  static const _maxReplayChars = 600;

  static String summaryOf(AssistantToolCall call) {
    final data = toolCallData(call);
    final cached = data.summary;
    final translations = l10n;
    if (cached != null && identical(cached.translations, translations)) {
      return cached.text;
    }
    final text =
        byId(call.name)?._summary(data.input, call.result, data.output) ??
        call.result;
    data.summary = (translations: translations, text: text);
    return text;
  }

  static void prepare(AssistantToolCall call) {
    if (call.done) summaryOf(call);
  }

  static bool get semanticAvailable =>
      getIt.isRegistered<EmbedIndexService>() &&
      getIt<EmbedIndexService>().enabled;

  static String recordOf(List<AssistantToolCall> calls) {
    final lines = <String>[];
    for (final call in calls) {
      if (!call.done) continue;
      final spec = byId(call.name);
      final args = call.argsJson.isEmpty ? '{}' : call.argsJson;
      if (spec != null && spec.replayResult && call.result.isNotEmpty) {
        final body = call.result.length > _maxReplayChars
            ? '${call.result.substring(0, _maxReplayChars)}…'
            : call.result;
        lines.add('- ${call.name}($args) →\n$body');
        continue;
      }
      final summary = spec == null ? '' : summaryOf(call);
      lines.add('- ${call.name}($args)${summary.isEmpty ? '' : ' → $summary'}');
    }
    return lines.isEmpty ? '' : '[tools already run]\n${lines.join('\n')}';
  }

  static AssistantToolSpec? byId(String id) => _byId[id];

  static List<AssistantToolSpec> specsFor(List<String>? allowed) {
    if (allowed == null) return specs;
    return [
      for (final spec in specs)
        if (allowed.contains(spec.id)) spec,
    ];
  }

  static String _summarizeQuery(Map<String, dynamic> input, String output) {
    final hit = RegExp(r'^(\d+) matches').firstMatch(output);
    if (hit == null) return l10n.assistant.toolNoMatch;
    final count = int.tryParse(hit.group(1) ?? '') ?? 0;
    return _querySummary(count, input);
  }

  static String _querySummary(int count, Map<String, dynamic> input) {
    if (count == 0) return l10n.assistant.toolNoMatch;
    final parts = <String>[
      l10n.assistant.toolMatched(count: count),
      ?_trimToNull(input['query']),
      if (_trimToNull(input['startDate']) case final a?)
        _trimToNull(input['endDate']) == null ? a : '$a – ${input['endDate']}',
    ];
    return parts.join(' · ');
  }

  static String _summarizeGet(Map<String, dynamic> input) =>
      l10n.assistant.toolRead(count: assistantToolIds(input).length);

  static String _summarizeStats(String output) {
    final hit = RegExp(r'^Total entries=(\d+)').firstMatch(output);
    final count = int.tryParse(hit?.group(1) ?? '') ?? 0;
    return l10n.assistant.toolMatched(count: count);
  }

  static String _summarizeList(String output) {
    final count = output.split('\n').where((e) => e.startsWith('id=')).length;
    return count == 0
        ? l10n.assistant.toolNoMatch
        : l10n.assistant.toolListed(count: count);
  }

  static String _summarizeDelete(Map<String, dynamic> input) => _writeSummary(
    AssistantTool.deleteDiary,
    assistantToolItems(input).length,
    const {},
  );

  static String _summarizeWrite(
    AssistantTool tool,
    Map<String, dynamic> input,
  ) {
    final items = assistantToolItems(input);
    return _writeSummary(
      tool,
      items.length,
      items.isEmpty ? const {} : items.first,
    );
  }

  static String _writeSummary(AssistantTool tool, int count, Map item) {
    if (tool == AssistantTool.deleteDiary) {
      return count <= 1
          ? l10n.assistant.toolTrashed
          : l10n.assistant.toolTrashedCount(count: count);
    }
    if (count > 1) {
      return switch (tool) {
        .createDiary ||
        .updateDiary => l10n.assistant.toolBatchDiaries(count: count),
        _ => l10n.assistant.toolBatchItems(count: count),
      };
    }
    return switch (tool) {
      .createDiary => _trimToNull(item['title']) ?? l10n.assistant.toolUntitled,
      .createCategory ||
      .updateCategory => _trimToNull(item['name']) ?? l10n.assistant.toolDone,
      .rememberFact => _trimToNull(item['text']) ?? l10n.assistant.toolDone,
      .deleteCategory || .forgetFact => l10n.assistant.toolDeleted,
      _ => l10n.assistant.toolUpdated,
    };
  }

  static String _summarizeJavascript(String output) {
    final line = output
        .split('\n')
        .firstWhere((e) => e.startsWith('Result: '), orElse: () => '');
    final value = line.replaceFirst('Result: ', '').trim();
    if (value.isEmpty || value == '(no value)') {
      return l10n.assistant.toolJsEmpty;
    }
    return value;
  }

  static String? _trimToNull(Object? raw) {
    final text = (raw as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
