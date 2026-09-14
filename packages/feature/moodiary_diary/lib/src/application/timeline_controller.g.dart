// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(timelineMonthCounts)
final timelineMonthCountsProvider = TimelineMonthCountsFamily._();

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
  TimelineMonthCountsProvider._({
    required TimelineMonthCountsFamily super.from,
    required ({String? categoryId, bool uncategorized, DiarySort sort})
    super.argument,
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
    final argument =
        this.argument
            as ({String? categoryId, bool uncategorized, DiarySort sort});
    return timelineMonthCounts(
      ref,
      categoryId: argument.categoryId,
      uncategorized: argument.uncategorized,
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
    r'274bc4691bf8e2f2da8b8e155f0b86761179a5ba';

final class TimelineMonthCountsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<DateTime, int>>,
          ({String? categoryId, bool uncategorized, DiarySort sort})
        > {
  TimelineMonthCountsFamily._()
    : super(
        retry: null,
        name: r'timelineMonthCountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TimelineMonthCountsProvider call({
    String? categoryId,
    bool uncategorized = false,
    required DiarySort sort,
  }) => TimelineMonthCountsProvider._(
    argument: (
      categoryId: categoryId,
      uncategorized: uncategorized,
      sort: sort,
    ),
    from: this,
  );

  @override
  String toString() => r'timelineMonthCountsProvider';
}
