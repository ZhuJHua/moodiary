// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_cloud_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 时间范围选择器要用的轻量索引：最早/最晚一篇 + 每月篇数。
/// 只看 `time` 一列，不碰正文。

@ProviderFor(wordCloudTimeIndex)
final wordCloudTimeIndexProvider = WordCloudTimeIndexProvider._();

/// 时间范围选择器要用的轻量索引：最早/最晚一篇 + 每月篇数。
/// 只看 `time` 一列，不碰正文。

final class WordCloudTimeIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})
          >,
          ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last}),
          FutureOr<
            ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})
          >
        >
    with
        $FutureModifier<
          ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})
        >,
        $FutureProvider<
          ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})
        > {
  /// 时间范围选择器要用的轻量索引：最早/最晚一篇 + 每月篇数。
  /// 只看 `time` 一列，不碰正文。
  WordCloudTimeIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordCloudTimeIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordCloudTimeIndexHash();

  @$internal
  @override
  $FutureProviderElement<
    ({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Map<DateTime, int> byMonth, DateTime? first, DateTime? last})>
  create(Ref ref) {
    return wordCloudTimeIndex(ref);
  }
}

String _$wordCloudTimeIndexHash() =>
    r'd85bedaa68b5762dbca5e6ec9659a091f7e62e66';

/// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
/// 日记一变（400ms 防抖）就重算。

@ProviderFor(wordCloudData)
final wordCloudDataProvider = WordCloudDataFamily._();

/// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
/// 日记一变（400ms 防抖）就重算。

final class WordCloudDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<WordCloudData>,
          WordCloudData,
          FutureOr<WordCloudData>
        >
    with $FutureModifier<WordCloudData>, $FutureProvider<WordCloudData> {
  /// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
  /// 日记一变（400ms 防抖）就重算。
  WordCloudDataProvider._({
    required WordCloudDataFamily super.from,
    required WordCloudTimeline super.argument,
  }) : super(
         retry: null,
         name: r'wordCloudDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wordCloudDataHash();

  @override
  String toString() {
    return r'wordCloudDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WordCloudData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WordCloudData> create(Ref ref) {
    final argument = this.argument as WordCloudTimeline;
    return wordCloudData(ref, timeline: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WordCloudDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wordCloudDataHash() => r'816e29184c6ce201b3618ea09adf50da3e8c613b';

/// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
/// 日记一变（400ms 防抖）就重算。

final class WordCloudDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WordCloudData>, WordCloudTimeline> {
  WordCloudDataFamily._()
    : super(
        retry: null,
        name: r'wordCloudDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 区间内所有日记的词云。屏蔽词/词典/单字开关一变就重算；
  /// 日记一变（400ms 防抖）就重算。

  WordCloudDataProvider call({required WordCloudTimeline timeline}) =>
      WordCloudDataProvider._(argument: timeline, from: this);

  @override
  String toString() => r'wordCloudDataProvider';
}
