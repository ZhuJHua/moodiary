import 'dart:convert';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import 'assistant_defs.dart';
import 'assistant_tool_definitions.dart';

class AssistantToolSpec {
  const AssistantToolSpec(this.definition);
  final ToolDefinition definition;
  String get id => definition.name;
  AssistantTool get tool =>
      AssistantTool.values.firstWhere((tool) => tool.id == id);
  String get description => definition.description(ToolSurface.assistant);
  Map<String, dynamic> get jsonSchema =>
      definition.input(ToolSurface.assistant).value;
  bool get replayResult => tool == AssistantTool.recallMemory;
  Future<String> run(Map<String, dynamic> input) async =>
      jsonEncode((await definition.call(input, assistantToolContext())).data);

  String summaryOf(Map<String, dynamic> input, String output) {
    if (output.startsWith('Failed:')) return l10n.assistant.toolFailed;
    if (output.startsWith(assistantToolSkippedPrefix)) {
      return l10n.assistant.toolSkipped;
    }
    Map<String, dynamic>? data;
    try {
      final raw = jsonDecode(output);
      if (raw is Map) data = raw.cast<String, dynamic>();
    } catch (_) {}
    if (data != null) return _jsonSummary(data, input);
    return switch (tool) {
      .searchDiaries => AssistantToolRegistry._summarizeQuery(
        tool,
        input,
        output,
      ),
      .getDiary => AssistantToolRegistry._summarizeGet(tool, input, output),
      .getStats => AssistantToolRegistry._summarizeStats(tool, input, output),
      .listCategories || .recallMemory || .listTags || .getDiaryLinks =>
        AssistantToolRegistry._summarizeList(tool, input, output),
      .deleteDiary => AssistantToolRegistry._summarizeDelete(
        tool,
        input,
        output,
      ),
      .runJavascript => AssistantToolRegistry._summarizeJavascript(
        tool,
        input,
        output,
      ),
      _ => AssistantToolRegistry._summarizeWrite(tool, input, output),
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
      if (tool == AssistantTool.deleteDiary) {
        return succeeded.length <= 1
            ? l10n.assistant.toolTrashed
            : l10n.assistant.toolTrashedCount(count: succeeded.length);
      }
      if (succeeded.length > 1) {
        return tool == AssistantTool.createDiary ||
                tool == AssistantTool.updateDiary
            ? l10n.assistant.toolBatchDiaries(count: succeeded.length)
            : l10n.assistant.toolBatchItems(count: succeeded.length);
      }
      if (succeeded.isEmpty) return l10n.assistant.toolNoMatch;
      final row = succeeded.single;
      return switch (tool) {
        .createDiary =>
          AssistantToolRegistry._trimToNull((row['diary'] as Map?)?['title']) ??
              l10n.assistant.toolUntitled,
        .createCategory || .updateCategory =>
          AssistantToolRegistry._trimToNull(
                (row['category'] as Map?)?['name'],
              ) ??
              l10n.assistant.toolDone,
        .rememberFact =>
          AssistantToolRegistry._trimToNull(row['text']) ??
              l10n.assistant.toolDone,
        .deleteCategory || .forgetFact => l10n.assistant.toolDeleted,
        _ => l10n.assistant.toolUpdated,
      };
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
  static const _maxReplayChars = 600;

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
        lines.add('- ${normalizeAssistantToolId(call.name)}($args) →\n$body');
        continue;
      }
      final summary = spec == null
          ? ''
          : spec.summaryOf(_decodeArgs(call.argsJson), call.result);
      lines.add(
        '- ${normalizeAssistantToolId(call.name)}($args)${summary.isEmpty ? '' : ' → $summary'}',
      );
    }
    return lines.isEmpty ? '' : '[tools already run]\n${lines.join('\n')}';
  }

  static Map<String, dynamic> _decodeArgs(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  static AssistantToolSpec? byId(String id) {
    for (final spec in specs) {
      if (spec.id == normalizeAssistantToolId(id)) return spec;
    }
    return null;
  }

  static List<AssistantToolSpec> specsFor(List<String>? allowed) {
    if (allowed == null) return specs;
    return [
      for (final spec in specs)
        if (allowed.map(normalizeAssistantToolId).contains(spec.id)) spec,
    ];
  }

  static String _summarizeQuery(
    AssistantTool _,
    Map<String, dynamic> input,
    String output,
  ) {
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

  static String _summarizeGet(
    AssistantTool _,
    Map<String, dynamic> input,
    String _,
  ) => l10n.assistant.toolRead(count: assistantToolIds(input).length);

  static String _summarizeStats(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
    final hit = RegExp(r'^Total entries=(\d+)').firstMatch(output);
    final count = int.tryParse(hit?.group(1) ?? '') ?? 0;
    return l10n.assistant.toolMatched(count: count);
  }

  static String _summarizeList(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
    final count = output.split('\n').where((e) => e.startsWith('id=')).length;
    return count == 0
        ? l10n.assistant.toolNoMatch
        : l10n.assistant.toolListed(count: count);
  }

  static String _summarizeDelete(
    AssistantTool _,
    Map<String, dynamic> input,
    String _,
  ) {
    final count = assistantToolItems(input).length;
    return count <= 1
        ? l10n.assistant.toolTrashed
        : l10n.assistant.toolTrashedCount(count: count);
  }

  static String _summarizeWrite(
    AssistantTool tool,
    Map<String, dynamic> input,
    String output,
  ) {
    final items = assistantToolItems(input);
    if (items.length > 1) {
      return switch (tool) {
        .createDiary ||
        .updateDiary => l10n.assistant.toolBatchDiaries(count: items.length),
        _ => l10n.assistant.toolBatchItems(count: items.length),
      };
    }
    final item = items.isEmpty ? const <String, dynamic>{} : items.first;
    return switch (tool) {
      .createDiary => _trimToNull(item['title']) ?? l10n.assistant.toolUntitled,
      .createCategory ||
      .updateCategory => _trimToNull(item['name']) ?? l10n.assistant.toolDone,
      .rememberFact => _trimToNull(item['text']) ?? l10n.assistant.toolDone,
      .deleteCategory || .forgetFact => l10n.assistant.toolDeleted,
      _ => l10n.assistant.toolUpdated,
    };
  }

  static String _summarizeJavascript(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
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
