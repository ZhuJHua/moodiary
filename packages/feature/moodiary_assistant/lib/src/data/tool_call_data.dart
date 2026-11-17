import 'dart:convert';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

Map<String, dynamic>? decodeJsonMap(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    return value is Map ? value.cast<String, dynamic>() : null;
  } on FormatException {
    return null;
  }
}

final _toolCallData = Expando<ToolCallData>();

ToolCallData toolCallData(AssistantToolCall call) =>
    _toolCallData[call] ??= ToolCallData(call);

class ToolCallData {
  ToolCallData(AssistantToolCall call)
    : input = decodeJsonMap(call.argsJson) ?? const {},
      output = decodeJsonMap(call.result) {
    diaryIds = _idsIn(output, call.result);
  }

  final Map<String, dynamic> input;
  final Map<String, dynamic>? output;
  late final List<String> diaryIds;
  ({Translations translations, String text})? summary;
}

// lookbehind 挡掉 categoryId= 一类；旧聊天保存的是文本工具结果。
final _diaryId = RegExp(r'(?<![A-Za-z])id=([0-9a-fA-F-]{16,})');

List<String> _idsIn(Map<String, dynamic>? data, String result) {
  if (data != null) return diaryIdsIn(data);
  return [
    for (final line in result.split('\n'))
      if (!line.startsWith('Failed') && !line.startsWith('Not found'))
        for (final match in _diaryId.allMatches(line)) match.group(1)!,
  ];
}
