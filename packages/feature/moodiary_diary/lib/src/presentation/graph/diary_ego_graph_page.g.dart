// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_ego_graph_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diaryEgoGraph)
final diaryEgoGraphProvider = DiaryEgoGraphFamily._();

final class DiaryEgoGraphProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiaryGraphData>,
          DiaryGraphData,
          FutureOr<DiaryGraphData>
        >
    with $FutureModifier<DiaryGraphData>, $FutureProvider<DiaryGraphData> {
  DiaryEgoGraphProvider._({
    required DiaryEgoGraphFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'diaryEgoGraphProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$diaryEgoGraphHash();

  @override
  String toString() {
    return r'diaryEgoGraphProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DiaryGraphData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DiaryGraphData> create(Ref ref) {
    final argument = this.argument as String;
    return diaryEgoGraph(ref, diaryId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryEgoGraphProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$diaryEgoGraphHash() => r'c4ec6f6ae3460d92b203a52b917797d222d85f59';

final class DiaryEgoGraphFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DiaryGraphData>, String> {
  DiaryEgoGraphFamily._()
    : super(
        retry: null,
        name: r'diaryEgoGraphProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DiaryEgoGraphProvider call({required String diaryId}) =>
      DiaryEgoGraphProvider._(argument: diaryId, from: this);

  @override
  String toString() => r'diaryEgoGraphProvider';
}
