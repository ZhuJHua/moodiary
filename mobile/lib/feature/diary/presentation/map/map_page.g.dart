// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diariesWithPosition)
final diariesWithPositionProvider = DiariesWithPositionProvider._();

final class DiariesWithPositionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Diary>>,
          List<Diary>,
          FutureOr<List<Diary>>
        >
    with $FutureModifier<List<Diary>>, $FutureProvider<List<Diary>> {
  DiariesWithPositionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diariesWithPositionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diariesWithPositionHash();

  @$internal
  @override
  $FutureProviderElement<List<Diary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Diary>> create(Ref ref) {
    return diariesWithPosition(ref);
  }
}

String _$diariesWithPositionHash() =>
    r'65a8cddfa50cc97e40f227102239d4f51ea483b7';
