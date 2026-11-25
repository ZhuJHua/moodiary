// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_catalog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tagCatalog)
final tagCatalogProvider = TagCatalogProvider._();

final class TagCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Map<String, Tag> byId, List<TagUsage> usage})>,
          ({Map<String, Tag> byId, List<TagUsage> usage}),
          FutureOr<({Map<String, Tag> byId, List<TagUsage> usage})>
        >
    with
        $FutureModifier<({Map<String, Tag> byId, List<TagUsage> usage})>,
        $FutureProvider<({Map<String, Tag> byId, List<TagUsage> usage})> {
  TagCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagCatalogHash();

  @$internal
  @override
  $FutureProviderElement<({Map<String, Tag> byId, List<TagUsage> usage})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Map<String, Tag> byId, List<TagUsage> usage})> create(Ref ref) {
    return tagCatalog(ref);
  }
}

String _$tagCatalogHash() => r'adc17883f56c5a71fd48cb604046fecea2273266';
