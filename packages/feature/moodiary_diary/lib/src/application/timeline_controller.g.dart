// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
///
/// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
/// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
/// 保持一致，否则表头数字会和它下面的条目对不上。

@ProviderFor(timelineMonthCounts)
final timelineMonthCountsProvider = TimelineMonthCountsFamily._();

/// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
///
/// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
/// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
/// 保持一致，否则表头数字会和它下面的条目对不上。

final class TimelineMonthCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<DateTime, int>>,
          Map<DateTime, int>,
          FutureOr<Map<DateTime, int>>
        >
    with
        $FutureModifier<Map<DateTime, int>>,
        $FutureProvider<Map<DateTime, int>> {
  /// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
  ///
  /// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
  /// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
  /// 保持一致，否则表头数字会和它下面的条目对不上。
  TimelineMonthCountsProvider._({
    required TimelineMonthCountsFamily super.from,
    required ({String? categoryId, DiarySort sort}) super.argument,
  }) : super(
         retry: null,
         name: r'timelineMonthCountsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$timelineMonthCountsHash();

  @override
  String toString() {
    return r'timelineMonthCountsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Map<DateTime, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<DateTime, int>> create(Ref ref) {
    final argument = this.argument as ({String? categoryId, DiarySort sort});
    return timelineMonthCounts(
      ref,
      categoryId: argument.categoryId,
      sort: argument.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TimelineMonthCountsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timelineMonthCountsHash() =>
    r'9c43c3ce3d1a2453833cd18a5393801a60f8de5d';

/// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
///
/// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
/// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
/// 保持一致，否则表头数字会和它下面的条目对不上。

final class TimelineMonthCountsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<DateTime, int>>,
          ({String? categoryId, DiarySort sort})
        > {
  TimelineMonthCountsFamily._()
    : super(
        retry: null,
        name: r'timelineMonthCountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 月份 -> 该月可见日记篇数（月首零点为键，本地时区）。
  ///
  /// 走独立的聚合查询而不是数首页那条分页列表：列表一次只加载 30 条，从中数出来的是
  /// 「加载到哪儿了」，不是这个月写了多少篇。[sort] 决定分桶字段，必须与时间线的分组键
  /// 保持一致，否则表头数字会和它下面的条目对不上。

  TimelineMonthCountsProvider call({
    String? categoryId,
    required DiarySort sort,
  }) => TimelineMonthCountsProvider._(
    argument: (categoryId: categoryId, sort: sort),
    from: this,
  );

  @override
  String toString() => r'timelineMonthCountsProvider';
}
