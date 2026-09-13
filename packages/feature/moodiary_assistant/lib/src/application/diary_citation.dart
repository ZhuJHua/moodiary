import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_models/moodiary_models.dart';

const String _citePrefix = '[diary:';

// 工具结果里的日记 id 都是 uuid；lookbehind 挡掉 categoryId= 一类
final RegExp _diaryId = RegExp(r'(?<![A-Za-z])id=([0-9a-fA-F-]{16,})');

enum DiaryCitationKind { read, created, updated, deleted }

typedef DiaryCitation = ({String id, DiaryCitationKind kind});

final Map<String, DiaryCitationKind> _kindByTool = {
  AssistantTool.searchDiaries.id: .read,
  AssistantTool.getDiary.id: .read,
  AssistantTool.createDiary.id: .created,
  AssistantTool.updateDiary.id: .updated,
  AssistantTool.deleteDiary.id: .deleted,
};

Iterable<String> _idsIn(String result) sync* {
  for (final line in result.split('\n')) {
    if (line.startsWith('Failed') || line.startsWith('Not found')) continue;
    for (final m in _diaryId.allMatches(line)) {
      yield m.group(1)!;
    }
  }
}

bool citesDiaries(AssistantToolCall call) =>
    call.done &&
    _kindByTool.containsKey(call.name) &&
    _idsIn(call.result).isNotEmpty;

List<DiaryCitation> diaryCitationsOf(Iterable<AssistantToolCall> calls) {
  final byId = <String, DiaryCitationKind>{};
  for (final call in calls) {
    final kind = _kindByTool[call.name];
    if (kind == null || !call.done) continue;
    for (final id in _idsIn(call.result)) {
      final seen = byId[id];
      if (seen == null || kind.index > seen.index) byId[id] = kind;
    }
  }
  return [for (final e in byId.entries) (id: e.key, kind: e.value)];
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
