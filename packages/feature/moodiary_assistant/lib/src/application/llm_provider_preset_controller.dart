import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_provider_preset_controller.g.dart';

@riverpod
class LlmProviderPresetController extends _$LlmProviderPresetController {
  @override
  Future<List<LlmProviderPreset>> build() {
    return getIt<LlmPresetRepository>().load();
  }
}
