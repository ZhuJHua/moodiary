// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_share.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diaryShareHandler)
final diaryShareHandlerProvider = DiaryShareHandlerProvider._();

final class DiaryShareHandlerProvider
    extends
        $FunctionalProvider<
          DiaryShareHandler,
          DiaryShareHandler,
          DiaryShareHandler
        >
    with $Provider<DiaryShareHandler> {
  DiaryShareHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diaryShareHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diaryShareHandlerHash();

  @$internal
  @override
  $ProviderElement<DiaryShareHandler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiaryShareHandler create(Ref ref) {
    return diaryShareHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiaryShareHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiaryShareHandler>(value),
    );
  }
}

String _$diaryShareHandlerHash() => r'737b238f43f5a75e434eb0290bc7aa9904c43026';
