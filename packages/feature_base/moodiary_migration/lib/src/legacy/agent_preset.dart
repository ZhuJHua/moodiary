// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'agent_preset.freezed.dart';
part 'agent_preset.g.dart';

@freezed
@Collection(ignore: {'copyWith'}, accessor: 'agentPresets')
abstract class AgentPreset with _$AgentPreset {
  const factory AgentPreset({
    @Id() required String id,

    required String name,

    @Default('') String description,

    required String persona,

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
