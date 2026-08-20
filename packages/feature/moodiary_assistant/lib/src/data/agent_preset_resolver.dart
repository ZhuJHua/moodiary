import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'assistant_defs.dart';

/// 一次会话 mount 的内容（dsh：创建时定格进会话）。[tools] null = 全部工具。
typedef AgentPresetMount = ({String persona, List<String>? tools});

/// 内置预设「Moodiary助手」+ 用户预设的合成视图。
///
/// data 层的 [AgentPresetRepository] 只管落库的用户行；内置项的人格是
/// [defaultPersona] 常量、名称走 l10n（由 UI 解析），所以合成发生在这里。
final class AgentPresetResolver {
  const AgentPresetResolver._();

  /// 解析一个预设 id 要 mount 的人格与工具子集；
  /// [builtinAgentPresetId] 或找不到（已删）→ 内置（出厂人格 + 全部工具）。
  static Future<AgentPresetMount> mountFor(String id) async {
    if (id == builtinAgentPresetId) {
      return (persona: defaultPersona, tools: null);
    }
    final preset = await AgentPresetRepository.get().get(id);
    if (preset == null) return (persona: defaultPersona, tools: null);
    return (persona: preset.persona, tools: preset.tools);
  }

  /// 新会话的默认预设 id：读 KV，指向的预设已被删则回落内置（并不回写 KV，
  /// 用户重建同名预设不会自动接管，回落只影响读取）。
  static Future<String> defaultId() async {
    final id = MoodiaryKVs.assistantAgentPresetId.get() ?? builtinAgentPresetId;
    if (id == builtinAgentPresetId) return builtinAgentPresetId;
    final preset = await AgentPresetRepository.get().get(id);
    return preset == null ? builtinAgentPresetId : id;
  }
}
