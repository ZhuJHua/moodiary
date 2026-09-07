import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

class ModelOption {
  final String id;

  final String label;

  final LlmModelPreset? preset;

  final List<String> levels;

  const ModelOption({
    required this.id,
    required this.label,
    required this.preset,
    required this.levels,
  });

  bool get deprecated => preset?.deprecated ?? false;
}

typedef ResolvedModel = ({
  AssistantProviderType protocol,
  String baseUrl,
  String modelId,
  LlmModelPreset? preset,
});

abstract final class ModelResolver {
  static ResolvedModel resolve(LlmProvider provider, [String modelId = '']) {
    final id = modelId.isEmpty ? provider.defaultModel : modelId;
    final preset = provider.isPreset ? _presetModel(provider, id) : null;
    return (
      protocol: preset?.protocol ?? provider.protocol,
      baseUrl: preset?.baseUrl ?? provider.baseUrl,
      modelId: id,
      preset: preset,
    );
  }

  static List<ModelOption> optionsFor(LlmProvider provider) {
    if (!provider.isPreset) {
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
    for (final preset in getIt<LlmPresetRepository>().cachedPresets()) {
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

  static List<String> levelsFor(LlmProvider provider, String modelId) {
    final preset = resolve(provider, modelId).preset;
    if (preset != null) return reasoningLevelsFor(preset);
    return provider.reasoning ? customReasoningLevels : const [];
  }

  static LlmModelPreset? _presetModel(LlmProvider provider, String modelId) {
    for (final preset in getIt<LlmPresetRepository>().cachedPresets()) {
      if (preset.id != provider.presetId) continue;
      for (final model in preset.models) {
        if (model.id == modelId) return model;
      }
    }
    return null;
  }
}
