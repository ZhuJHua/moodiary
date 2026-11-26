// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(_platformDirectories)
final _platformDirectoriesProvider = _PlatformDirectoriesProvider._();

final class _PlatformDirectoriesProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  _PlatformDirectoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_platformDirectoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_platformDirectoriesHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return _platformDirectories(ref);
  }
}

String _$_platformDirectoriesHash() =>
    r'5cd10b0bc55cc6c1aa0972c3312d9ea1d05bb081';

@ProviderFor(_dataStartup)
final _dataStartupProvider = _DataStartupProvider._();

final class _DataStartupProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  _DataStartupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_dataStartupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_dataStartupHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return _dataStartup(ref);
  }
}

String _$_dataStartupHash() => r'da0a944d37682ee6d35eeb62eccd7e757fb7dd26';

@ProviderFor(resetDataAction)
final resetDataActionProvider = ResetDataActionProvider._();

final class ResetDataActionProvider
    extends
        $FunctionalProvider<
          Future<void> Function(),
          Future<void> Function(),
          Future<void> Function()
        >
    with $Provider<Future<void> Function()> {
  ResetDataActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resetDataActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resetDataActionHash();

  @$internal
  @override
  $ProviderElement<Future<void> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<void> Function() create(Ref ref) {
    return resetDataAction(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<void> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<void> Function()>(value),
    );
  }
}

String _$resetDataActionHash() => r'2405e7668f31181c85fd84ee43bbf0ae01e3a665';
