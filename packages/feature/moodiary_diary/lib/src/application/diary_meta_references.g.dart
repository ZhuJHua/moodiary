// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_meta_references.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diaryMetaReferences)
final diaryMetaReferencesProvider = DiaryMetaReferencesFamily._();

final class DiaryMetaReferencesProvider
    extends
        $FunctionalProvider<
          DiaryMetaReferences,
          DiaryMetaReferences,
          DiaryMetaReferences
        >
    with $Provider<DiaryMetaReferences> {
  DiaryMetaReferencesProvider._({
    required DiaryMetaReferencesFamily super.from,
    required ({String? categoryId, String? placeId}) super.argument,
  }) : super(
         retry: null,
         name: r'diaryMetaReferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$diaryMetaReferencesHash();

  @override
  String toString() {
    return r'diaryMetaReferencesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<DiaryMetaReferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiaryMetaReferences create(Ref ref) {
    final argument = this.argument as ({String? categoryId, String? placeId});
    return diaryMetaReferences(
      ref,
      categoryId: argument.categoryId,
      placeId: argument.placeId,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiaryMetaReferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiaryMetaReferences>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryMetaReferencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$diaryMetaReferencesHash() =>
    r'2546f7dd86d835fd6b400d15de653058f59fe599';

final class DiaryMetaReferencesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          DiaryMetaReferences,
          ({String? categoryId, String? placeId})
        > {
  DiaryMetaReferencesFamily._()
    : super(
        retry: null,
        name: r'diaryMetaReferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DiaryMetaReferencesProvider call({String? categoryId, String? placeId}) =>
      DiaryMetaReferencesProvider._(
        argument: (categoryId: categoryId, placeId: placeId),
        from: this,
      );

  @override
  String toString() => r'diaryMetaReferencesProvider';
}
