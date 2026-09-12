import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_models/moodiary_models.dart';

const String _citePrefix = '[diary:';

final RegExp _idLine = RegExp(r'^id=(\S+)', multiLine: true);

final Set<String> diaryReadTools = {
  AssistantTool.queryDiaries.id,
  AssistantTool.semanticSearchDiaries.id,
  AssistantTool.getDiary.id,
};

bool citesDiaries(AssistantToolCall call) =>
    call.done &&
    diaryReadTools.contains(call.name) &&
    _idLine.hasMatch(call.result);

List<String> citedDiaryIdsOf(Iterable<AssistantToolCall> calls) {
  final seen = <String>{};
  final out = <String>[];
  for (final call in calls) {
    if (!call.done || !diaryReadTools.contains(call.name)) continue;
    for (final m in _idLine.allMatches(call.result)) {
      final id = m.group(1)!;
      if (seen.add(id)) out.add(id);
    }
  }
  return out;
}

String citeDiary(String text, String diaryId) => '$_citePrefix$diaryId]\n$text';

({String? diaryId, String text}) splitDiaryCitation(String text) {
  if (!text.startsWith(_citePrefix)) return (diaryId: null, text: text);
  final end = text.indexOf(']');
  if (end == -1) return (diaryId: null, text: text);
  final id = text.substring(_citePrefix.length, end);
  if (id.isEmpty) return (diaryId: null, text: text);
  var rest = text.substring(end + 1);
  if (rest.startsWith('\n')) rest = rest.substring(1);
  return (diaryId: id, text: rest);
}

String diaryCitationForModel(String text) {
  final (:diaryId, text: body) = splitDiaryCitation(text);
  if (diaryId == null) return text;
  return 'The user is asking about the diary with id=$diaryId. '
      'Read it with getDiary before answering.\n\n$body';
}
