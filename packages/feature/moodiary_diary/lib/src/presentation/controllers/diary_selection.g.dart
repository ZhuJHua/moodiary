// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiarySelection)
final diarySelectionProvider = DiarySelectionProvider._();

final class DiarySelectionProvider
    extends $NotifierProvider<DiarySelection, Set<String>> {
  DiarySelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diarySelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diarySelectionHash();

  @$internal
  @override
  DiarySelection create() => DiarySelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$diarySelectionHash() => r'3edce5139133c3b5b1f898c6944c9e00d7b42ab0';

abstract class _$DiarySelection extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
