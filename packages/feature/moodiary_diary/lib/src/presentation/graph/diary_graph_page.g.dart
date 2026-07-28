// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_graph_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 知识图谱数据（只含有双链的日记）。订阅 [DiaryRepository.diaryEvents]，任何日记增删改都
/// 令其失效重建；从双链快照直接装配，免解析 content。
///
/// 事件做 400ms 防抖：同步拉取 / 批量编辑会连续触发多次，不防抖就是连续多次全量重建。

@ProviderFor(diaryGraph)
final diaryGraphProvider = DiaryGraphProvider._();

/// 知识图谱数据（只含有双链的日记）。订阅 [DiaryRepository.diaryEvents]，任何日记增删改都
/// 令其失效重建；从双链快照直接装配，免解析 content。
///
/// 事件做 400ms 防抖：同步拉取 / 批量编辑会连续触发多次，不防抖就是连续多次全量重建。

final class DiaryGraphProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiaryGraphData>,
          DiaryGraphData,
          FutureOr<DiaryGraphData>
        >
    with $FutureModifier<DiaryGraphData>, $FutureProvider<DiaryGraphData> {
  /// 知识图谱数据（只含有双链的日记）。订阅 [DiaryRepository.diaryEvents]，任何日记增删改都
  /// 令其失效重建；从双链快照直接装配，免解析 content。
  ///
  /// 事件做 400ms 防抖：同步拉取 / 批量编辑会连续触发多次，不防抖就是连续多次全量重建。
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

String _$diaryGraphHash() => r'f0f3e57b69ff434284f8214db19f77ceed080b2e';
