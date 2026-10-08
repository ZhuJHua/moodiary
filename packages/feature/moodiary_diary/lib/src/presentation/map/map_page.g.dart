// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(footprints)
final footprintsProvider = FootprintsProvider._();

final class FootprintsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Footprint>>,
          List<Footprint>,
          FutureOr<List<Footprint>>
        >
    with $FutureModifier<List<Footprint>>, $FutureProvider<List<Footprint>> {
  FootprintsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'footprintsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$footprintsHash();

  @$internal
  @override
  $FutureProviderElement<List<Footprint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Footprint>> create(Ref ref) {
    return footprints(ref);
  }
}

String _$footprintsHash() => r'7220824fc8c5cbc06cf24542dc65e6251f8085de';
