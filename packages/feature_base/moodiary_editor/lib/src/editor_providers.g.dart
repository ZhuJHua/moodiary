// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(geoRepository)
final geoRepositoryProvider = GeoRepositoryProvider._();

final class GeoRepositoryProvider
    extends $FunctionalProvider<GeoRepository, GeoRepository, GeoRepository>
    with $Provider<GeoRepository> {
  GeoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geoRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geoRepositoryHash();

  @$internal
  @override
  $ProviderElement<GeoRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GeoRepository create(Ref ref) {
    return geoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeoRepository>(value),
    );
  }
}

String _$geoRepositoryHash() => r'a00d12fc2c55025864bd2219c0290a78476f75c4';

@ProviderFor(weatherRepository)
final weatherRepositoryProvider = WeatherRepositoryProvider._();

final class WeatherRepositoryProvider
    extends
        $FunctionalProvider<
          WeatherRepository,
          WeatherRepository,
          WeatherRepository
        >
    with $Provider<WeatherRepository> {
  WeatherRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weatherRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weatherRepositoryHash();

  @$internal
  @override
  $ProviderElement<WeatherRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WeatherRepository create(Ref ref) {
    return weatherRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeatherRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeatherRepository>(value),
    );
  }
}

String _$weatherRepositoryHash() => r'c85d4c8c55b86c57b4f5711af9c33cb9cccd9e61';
