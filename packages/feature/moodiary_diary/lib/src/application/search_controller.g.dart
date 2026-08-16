// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiarySearchController)
final diarySearchControllerProvider = DiarySearchControllerProvider._();

final class DiarySearchControllerProvider
    extends $NotifierProvider<DiarySearchController, DiarySearchState> {
  DiarySearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diarySearchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diarySearchControllerHash();

  @$internal
  @override
  DiarySearchController create() => DiarySearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiarySearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiarySearchState>(value),
    );
  }
}

String _$diarySearchControllerHash() =>
    r'06080613c6e6980fa556e7e59aacc2f7281dc92f';

abstract class _$DiarySearchController extends $Notifier<DiarySearchState> {
  DiarySearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiarySearchState, DiarySearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiarySearchState, DiarySearchState>,
              DiarySearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
