// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FontController)
final fontControllerProvider = FontControllerProvider._();

final class FontControllerProvider
    extends $AsyncNotifierProvider<FontController, List<Font>> {
  FontControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontControllerHash();

  @$internal
  @override
  FontController create() => FontController();
}

String _$fontControllerHash() => r'ebc86a2829e397ff770a1e3157123437cc7ce283';

abstract class _$FontController extends $AsyncNotifier<List<Font>> {
  FutureOr<List<Font>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Font>>, List<Font>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Font>>, List<Font>>,
              AsyncValue<List<Font>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
