// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlaceController)
final placeControllerProvider = PlaceControllerProvider._();

final class PlaceControllerProvider
    extends $AsyncNotifierProvider<PlaceController, List<Place>> {
  PlaceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeControllerHash();

  @$internal
  @override
  PlaceController create() => PlaceController();
}

String _$placeControllerHash() => r'cd27cb9c32dbfb384292d4d96a60017a1e3cdd15';

abstract class _$PlaceController extends $AsyncNotifier<List<Place>> {
  FutureOr<List<Place>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Place>>, List<Place>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Place>>, List<Place>>,
              AsyncValue<List<Place>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(orderedPlaces)
final orderedPlacesProvider = OrderedPlacesProvider._();

final class OrderedPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Place>>,
          AsyncValue<List<Place>>,
          AsyncValue<List<Place>>
        >
    with $Provider<AsyncValue<List<Place>>> {
  OrderedPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderedPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderedPlacesHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<Place>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<Place>> create(Ref ref) {
    return orderedPlaces(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<Place>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<Place>>>(value),
    );
  }
}

String _$orderedPlacesHash() => r'7626954db1c7ea5ad1ffdc07141134154dabc477';

@ProviderFor(placeById)
final placeByIdProvider = PlaceByIdFamily._();

final class PlaceByIdProvider
    extends $FunctionalProvider<Place?, Place?, Place?>
    with $Provider<Place?> {
  PlaceByIdProvider._({
    required PlaceByIdFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'placeByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placeByIdHash();

  @override
  String toString() {
    return r'placeByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Place?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Place? create(Ref ref) {
    final argument = this.argument as String?;
    return placeById(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Place? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Place?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlaceByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placeByIdHash() => r'0497f60514a0d0d7735df7a99fa4e0d8c1595cd9';

final class PlaceByIdFamily extends $Family
    with $FunctionalFamilyOverride<Place?, String?> {
  PlaceByIdFamily._()
    : super(
        retry: null,
        name: r'placeByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlaceByIdProvider call(String? id) =>
      PlaceByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'placeByIdProvider';
}

@ProviderFor(placeFootprints)
final placeFootprintsProvider = PlaceFootprintsProvider._();

final class PlaceFootprintsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, PlaceFootprint>>,
          Map<String, PlaceFootprint>,
          FutureOr<Map<String, PlaceFootprint>>
        >
    with
        $FutureModifier<Map<String, PlaceFootprint>>,
        $FutureProvider<Map<String, PlaceFootprint>> {
  PlaceFootprintsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeFootprintsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeFootprintsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, PlaceFootprint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, PlaceFootprint>> create(Ref ref) {
    return placeFootprints(ref);
  }
}

String _$placeFootprintsHash() => r'3503d9864260ca396a2c64d771065bc50f721df0';
