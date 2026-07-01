// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider_preset_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 远端预设列表状态：build 走缓存优先的 load；refresh 强拉时保留旧值，避免刷新瞬间闪空。

@ProviderFor(LlmProviderPresetController)
final llmProviderPresetControllerProvider =
    LlmProviderPresetControllerProvider._();

/// 远端预设列表状态：build 走缓存优先的 load；refresh 强拉时保留旧值，避免刷新瞬间闪空。
final class LlmProviderPresetControllerProvider
    extends
        $AsyncNotifierProvider<
          LlmProviderPresetController,
          List<LlmProviderPreset>
        > {
  /// 远端预设列表状态：build 走缓存优先的 load；refresh 强拉时保留旧值，避免刷新瞬间闪空。
  LlmProviderPresetControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmProviderPresetControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmProviderPresetControllerHash();

  @$internal
  @override
  LlmProviderPresetController create() => LlmProviderPresetController();
}

String _$llmProviderPresetControllerHash() =>
    r'db79cb2c7a68391f01df20761eb9020285498184';

/// 远端预设列表状态：build 走缓存优先的 load；refresh 强拉时保留旧值，避免刷新瞬间闪空。

abstract class _$LlmProviderPresetController
    extends $AsyncNotifier<List<LlmProviderPreset>> {
  FutureOr<List<LlmProviderPreset>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<LlmProviderPreset>>,
              List<LlmProviderPreset>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<LlmProviderPreset>>,
                List<LlmProviderPreset>
              >,
              AsyncValue<List<LlmProviderPreset>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
