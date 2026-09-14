// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_graph_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diaryGraph)
final diaryGraphProvider = DiaryGraphProvider._();

final class DiaryGraphProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiaryGraphData>,
          DiaryGraphData,
          FutureOr<DiaryGraphData>
        >
    with $FutureModifier<DiaryGraphData>, $FutureProvider<DiaryGraphData> {
  DiaryGraphProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diaryGraphProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diaryGraphHash();

  @$internal
  @override
  $FutureProviderElement<DiaryGraphData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DiaryGraphData> create(Ref ref) {
    return diaryGraph(ref);
  }
}

String _$diaryGraphHash() => r'87807fe1885a49e512d71680c747b163eee5f36a';
