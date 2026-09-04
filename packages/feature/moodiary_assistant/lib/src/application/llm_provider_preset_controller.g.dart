// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider_preset_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LlmProviderPresetController)
final llmProviderPresetControllerProvider =
    LlmProviderPresetControllerProvider._();

final class LlmProviderPresetControllerProvider
    extends
        $AsyncNotifierProvider<
          LlmProviderPresetController,
          List<LlmProviderPreset>
        > {
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
    r'518d147ae3807dd27ceef8dfc641e0acf5dbbb33';

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
