import 'package:moodiary_assistant/src/data/agent_preset_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'assistant_defs.dart';

typedef AgentPresetMount = ({String persona, List<String>? tools});

final class AgentPresetResolver {
  const AgentPresetResolver._();

  static Future<AgentPresetMount> mountFor(String id) async {
    if (id == builtinAgentPresetId) {
      return (persona: defaultPersona, tools: null);
    }
    final preset = await getIt<AgentPresetRepository>().get(id);
    if (preset == null) return (persona: defaultPersona, tools: null);
    return (persona: preset.persona, tools: preset.tools);
  }

  static Future<String> defaultId() async {
    final id = MoodiaryKVs.assistantAgentPresetId.get() ?? builtinAgentPresetId;
    if (id == builtinAgentPresetId) return builtinAgentPresetId;
    final preset = await getIt<AgentPresetRepository>().get(id);
    return preset == null ? builtinAgentPresetId : id;
  }
}
