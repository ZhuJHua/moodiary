// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_insights_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MoodInsightsController)
final moodInsightsControllerProvider = MoodInsightsControllerProvider._();

final class MoodInsightsControllerProvider
    extends
        $AsyncNotifierProvider<MoodInsightsController, MoodInsightsCardData> {
  MoodInsightsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moodInsightsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moodInsightsControllerHash();

  @$internal
  @override
  MoodInsightsController create() => MoodInsightsController();
}

String _$moodInsightsControllerHash() =>
    r'7126961e8666b72cc0177ea4496964681f4bff76';

abstract class _$MoodInsightsController
    extends $AsyncNotifier<MoodInsightsCardData> {
  FutureOr<MoodInsightsCardData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<MoodInsightsCardData>, MoodInsightsCardData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MoodInsightsCardData>,
                MoodInsightsCardData
              >,
              AsyncValue<MoodInsightsCardData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
