// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appUpdateRepository)
final appUpdateRepositoryProvider = AppUpdateRepositoryProvider._();

final class AppUpdateRepositoryProvider
    extends
        $FunctionalProvider<
          AppUpdateRepository,
          AppUpdateRepository,
          AppUpdateRepository
        >
    with $Provider<AppUpdateRepository> {
  AppUpdateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppUpdateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppUpdateRepository create(Ref ref) {
    return appUpdateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUpdateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUpdateRepository>(value),
    );
  }
}

String _$appUpdateRepositoryHash() =>
    r'e8c7bd3d631cf1796aa567c7897477f8777713f6';
