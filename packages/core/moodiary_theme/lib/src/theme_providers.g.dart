// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(themeBuilder)
final themeBuilderProvider = ThemeBuilderProvider._();

final class ThemeBuilderProvider
    extends $FunctionalProvider<ThemeBuilder, ThemeBuilder, ThemeBuilder>
    with $Provider<ThemeBuilder> {
  ThemeBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeBuilderHash();

  @$internal
  @override
  $ProviderElement<ThemeBuilder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeBuilder create(Ref ref) {
    return themeBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeBuilder>(value),
    );
  }
}

String _$themeBuilderHash() => r'b771c33352135284c8b0435a2ac927de72de7005';
