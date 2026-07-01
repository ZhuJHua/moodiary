import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/assistant/data/llm_preset_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_provider_preset_controller.g.dart';

/// 远端预设列表状态：build 走缓存优先的 load；refresh 强拉时保留旧值，避免刷新瞬间闪空。
@riverpod
class LlmProviderPresetController extends _$LlmProviderPresetController {
  @override
  Future<List<LlmProviderPreset>> build() {
    return LlmPresetRepository.get().load();
  }

  /// 刷新期间不切 loading（旧列表保持可见）；失败时有列表则保留旧值并 rethrow。
  Future<void> refresh() async {
    final result = await AsyncValue.guard(LlmPresetRepository.get().refresh);
    if (result.hasError && state.hasValue) {
      throw result.error!;
    }
    state = result;
  }
}
