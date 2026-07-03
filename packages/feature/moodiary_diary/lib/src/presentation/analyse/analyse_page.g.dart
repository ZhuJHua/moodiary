// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analyse_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allShownDiaries)
final allShownDiariesProvider = AllShownDiariesProvider._();

final class AllShownDiariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Diary>>,
          List<Diary>,
          FutureOr<List<Diary>>
        >
    with $FutureModifier<List<Diary>>, $FutureProvider<List<Diary>> {
  AllShownDiariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allShownDiariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allShownDiariesHash();

  @$internal
  @override
  $FutureProviderElement<List<Diary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Diary>> create(Ref ref) {
    return allShownDiaries(ref);
  }
}

String _$allShownDiariesHash() => r'd7ede477fd0f287bbece08081e0792e855d697f3';
