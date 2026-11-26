// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_filter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeDiaryFilter)
final homeDiaryFilterProvider = HomeDiaryFilterProvider._();

final class HomeDiaryFilterProvider
    extends $NotifierProvider<HomeDiaryFilter, DiaryFilter> {
  HomeDiaryFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeDiaryFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeDiaryFilterHash();

  @$internal
  @override
  HomeDiaryFilter create() => HomeDiaryFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiaryFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiaryFilter>(value),
    );
  }
}

String _$homeDiaryFilterHash() => r'90ec4f5020ee17b1ed94620f3af0ae2f1c19699e';

abstract class _$HomeDiaryFilter extends $Notifier<DiaryFilter> {
  DiaryFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiaryFilter, DiaryFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiaryFilter, DiaryFilter>,
              DiaryFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
