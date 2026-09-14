// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_key_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SyncDekController)
final syncDekControllerProvider = SyncDekControllerProvider._();

final class SyncDekControllerProvider
    extends $AsyncNotifierProvider<SyncDekController, String?> {
  SyncDekControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDekControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDekControllerHash();

  @$internal
  @override
  SyncDekController create() => SyncDekController();
}

String _$syncDekControllerHash() => r'61d3e7d5b007b647ee005c96c0d566d772ac4c12';

abstract class _$SyncDekController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
