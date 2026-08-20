// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CacheController)
final cacheControllerProvider = CacheControllerProvider._();

final class CacheControllerProvider
    extends $AsyncNotifierProvider<CacheController, CacheUsage> {
  CacheControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheControllerHash();

  @$internal
  @override
  CacheController create() => CacheController();
}

String _$cacheControllerHash() => r'76d3c5c243c972cff98105bacce57d2d0132a477';

abstract class _$CacheController extends $AsyncNotifier<CacheUsage> {
  FutureOr<CacheUsage> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CacheUsage>, CacheUsage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CacheUsage>, CacheUsage>,
              AsyncValue<CacheUsage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
