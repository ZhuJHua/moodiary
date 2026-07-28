// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_ego_graph_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
/// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。

@ProviderFor(diaryEgoGraph)
final diaryEgoGraphProvider = DiaryEgoGraphFamily._();

/// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
/// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。

final class DiaryEgoGraphProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiaryGraphData>,
          DiaryGraphData,
          FutureOr<DiaryGraphData>
        >
    with $FutureModifier<DiaryGraphData>, $FutureProvider<DiaryGraphData> {
  /// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
  /// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。
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

String _$diaryEgoGraphHash() => r'777998a10bdfca569da6642f191ce441707162ca';

/// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
/// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。

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

  /// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
  /// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。

  DiaryEgoGraphProvider call({required String diaryId}) =>
      DiaryEgoGraphProvider._(argument: diaryId, from: this);

  @override
  String toString() => r'diaryEgoGraphProvider';
}
