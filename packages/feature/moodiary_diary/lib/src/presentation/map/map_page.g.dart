// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mapData)
final mapDataProvider = MapDataProvider._();

final class MapDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<({List<PlacePin> pins, String tiandituKey})>,
          ({List<PlacePin> pins, String tiandituKey}),
          FutureOr<({List<PlacePin> pins, String tiandituKey})>
        >
    with
        $FutureModifier<({List<PlacePin> pins, String tiandituKey})>,
        $FutureProvider<({List<PlacePin> pins, String tiandituKey})> {
  MapDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapDataHash();

  @$internal
  @override
  $FutureProviderElement<({List<PlacePin> pins, String tiandituKey})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({List<PlacePin> pins, String tiandituKey})> create(Ref ref) {
    return mapData(ref);
  }
}

String _$mapDataHash() => r'fd0a56b4716c6e1f59b1339b8fecbf38f1ae2680';
