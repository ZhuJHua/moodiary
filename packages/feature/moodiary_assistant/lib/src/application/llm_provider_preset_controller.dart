import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_provider_preset_controller.g.dart';

@riverpod
class LlmProviderPresetController extends _$LlmProviderPresetController {
  @override
  Future<List<LlmProviderPreset>> build() {
    return LlmPresetRepository.get().load();
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(LlmPresetRepository.get().refresh);
    if (result.hasError && state.hasValue) {
      throw result.error!;
    }
    state = result;
  }
}
