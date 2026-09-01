import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 一款模型的可选项（选择器用）。
class ModelOption {
  final String id;

  /// 目录里的显示名；自定义供应商没有目录，回落到 id 本身。
  final String label;

  /// 目录条目。自定义供应商为 null。
  final LlmModelPreset? preset;

  /// 可选的思考档位（不含「关」）。空表示不给强度控件。
  final List<String> levels;

  const ModelOption({
    required this.id,
    required this.label,
    required this.preset,
    required this.levels,
  });

  bool get deprecated => preset?.deprecated ?? false;
}

/// 一次请求要用的线路 + 模型元数据。
typedef ResolvedModel = ({
  AssistantProviderType protocol,
  String baseUrl,
  String modelId,
  LlmModelPreset? preset,
});

/// 供应商 + 模型 id → 实际线路。
///
/// **协议与 baseUrl 对 preset 供应商是按模型解析的**：中转站底下 Claude 走
/// messages、GPT 走 responses，同一家内部就分叉（目录里有 154 个模型的 npm 与
/// 供应商级不同）。自定义供应商没有目录，其下所有模型共用供应商自己那套。
abstract final class ModelResolver {
  /// [modelId] 留空表示用供应商的默认模型。只查本地目录缓存，绝不联网。
  static ResolvedModel resolve(LlmProvider provider, [String modelId = '']) {
    final id = modelId.isEmpty ? provider.defaultModel : modelId;
    final preset = provider.isPreset ? _presetModel(provider, id) : null;
    // 目录未命中（缓存还没拉到 / 模型已下架）时回落到供应商自己的协议，
    // 让对话仍能发出去而不是直接哑掉。
    return (
      protocol: preset?.protocol ?? provider.protocol,
      baseUrl: preset?.baseUrl ?? provider.baseUrl,
      modelId: id,
      preset: preset,
    );
  }

  /// 某供应商下可选的全部模型。preset 走目录，自定义走它自己存的列表。
  static List<ModelOption> optionsFor(LlmProvider provider) {
    if (!provider.isPreset) {
      // 默认模型可能是手填的、不在拉取列表里，补进去免得选择器里看不到当前项。
      final ids = <String>{...provider.models};
      if (provider.defaultModel.isNotEmpty) ids.add(provider.defaultModel);
      final levels = provider.reasoning
          ? customReasoningLevels
          : const <String>[];
      return [
        for (final id in ids.toList()..sort())
          ModelOption(id: id, label: id, preset: null, levels: levels),
      ];
    }
    for (final preset in LlmPresetRepository.get().cachedPresets()) {
      if (preset.id != provider.presetId) continue;
      return [
        for (final m in preset.models)
          ModelOption(
            id: m.id,
            label: m.name,
            preset: m,
            levels: reasoningLevelsFor(m),
          ),
      ];
    }
    return const [];
  }

  /// 某个模型可选的思考档位。
  static List<String> levelsFor(LlmProvider provider, String modelId) {
    final preset = resolve(provider, modelId).preset;
    if (preset != null) return reasoningLevelsFor(preset);
    return provider.reasoning ? customReasoningLevels : const [];
  }

  static LlmModelPreset? _presetModel(LlmProvider provider, String modelId) {
    for (final preset in LlmPresetRepository.get().cachedPresets()) {
      if (preset.id != provider.presetId) continue;
      for (final model in preset.models) {
        if (model.id == modelId) return model;
      }
    }
    return null;
  }
}
