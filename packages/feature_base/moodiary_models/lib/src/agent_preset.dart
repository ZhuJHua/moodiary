import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'agent_preset.freezed.dart';
part 'agent_preset.g.dart';

/// 一个用户自建的助手预设（人格）。
///
/// 内置预设「Moodiary助手」不落库：它由代码解析（persona 是英文常量，名称走 l10n），
/// 出厂人格随 App 升级自动更新。参考 dsh 的 agent-preset：预设**不拥有模型路由**，
/// 只有人格；会话创建时把 persona 快照进 [ChatSession]，之后编辑/删除不回读。
///
/// 仅设备本地：不进备份、不进同步。
@freezed
abstract class AgentPreset with _$AgentPreset {
  const factory AgentPreset({
    required String id,

    required String name,

    @Default('') String description,

    /// 人格文本（system prompt 的 order-0 段），上限由写入方截断。
    required String persona,

    /// 本预设挂载的工具 id 子集（dsh：预设声明它 mount 哪些工具）。
    /// null = 全部（跟随出厂全集，含未来新增）；空列表 = 一个工具都不挂。
    List<String>? tools,

    required DateTime createdAt,

    required DateTime updatedAt,
  }) = _AgentPreset;

  factory AgentPreset.create({
    required String name,
    required String persona,
    String description = '',
    List<String>? tools,
  }) {
    final now = DateTime.timestamp();
    return AgentPreset(
      id: uuidV7(),
      name: name,
      description: description,
      persona: persona,
      tools: tools,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AgentPreset.fromJson(Map<String, dynamic> json) =>
      _$AgentPresetFromJson(json);
}
