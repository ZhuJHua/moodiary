// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(httpClient)
final httpClientProvider = HttpClientProvider._();

final class HttpClientProvider
    extends $FunctionalProvider<IHttpClient, IHttpClient, IHttpClient>
    with $Provider<IHttpClient> {
  HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpClientHash();

  @$internal
  @override
  $ProviderElement<IHttpClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IHttpClient create(Ref ref) {
    return httpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IHttpClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IHttpClient>(value),
    );
  }
}

String _$httpClientHash() => r'f674f3e8bc83e1c1084c75423765d923bea214e7';

@ProviderFor(httpServerFactory)
final httpServerFactoryProvider = HttpServerFactoryProvider._();

final class HttpServerFactoryProvider
    extends
        $FunctionalProvider<
          HttpServerFactory,
          HttpServerFactory,
          HttpServerFactory
        >
    with $Provider<HttpServerFactory> {
  HttpServerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpServerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpServerFactoryHash();

  @$internal
  @override
  $ProviderElement<HttpServerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HttpServerFactory create(Ref ref) {
    return httpServerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HttpServerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HttpServerFactory>(value),
    );
  }
}

String _$httpServerFactoryHash() => r'ac2042296cb5829694113a6020d674a75a13d363';
