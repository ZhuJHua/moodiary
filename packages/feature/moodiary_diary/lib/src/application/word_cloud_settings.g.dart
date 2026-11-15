// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_cloud_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 屏蔽词：加进来的词一定不出现在词云里。

@ProviderFor(WordCloudBlocked)
final wordCloudBlockedProvider = WordCloudBlockedProvider._();

/// 屏蔽词：加进来的词一定不出现在词云里。
final class WordCloudBlockedProvider
    extends $NotifierProvider<WordCloudBlocked, List<String>> {
  /// 屏蔽词：加进来的词一定不出现在词云里。
  WordCloudBlockedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordCloudBlockedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordCloudBlockedHash();

  @$internal
  @override
  WordCloudBlocked create() => WordCloudBlocked();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$wordCloudBlockedHash() => r'd5623e29b3bd838b1906114e52d906b589e6cc37';

/// 屏蔽词：加进来的词一定不出现在词云里。

abstract class _$WordCloudBlocked extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 自定义词典：按整词统计，用来修正 jieba 的错切；同时是「保留名单」
/// （优先于内置停用词表，所以内置表误砍的实义词可以在这里找回来）。

@ProviderFor(WordCloudLexiconList)
final wordCloudLexiconListProvider = WordCloudLexiconListProvider._();

/// 自定义词典：按整词统计，用来修正 jieba 的错切；同时是「保留名单」
/// （优先于内置停用词表，所以内置表误砍的实义词可以在这里找回来）。
final class WordCloudLexiconListProvider
    extends $NotifierProvider<WordCloudLexiconList, List<String>> {
  /// 自定义词典：按整词统计，用来修正 jieba 的错切；同时是「保留名单」
  /// （优先于内置停用词表，所以内置表误砍的实义词可以在这里找回来）。
  WordCloudLexiconListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordCloudLexiconListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordCloudLexiconListHash();

  @$internal
  @override
  WordCloudLexiconList create() => WordCloudLexiconList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$wordCloudLexiconListHash() =>
    r'e2b3eb951f803fb5a7e2ff46e2e65df7b610b07a';

/// 自定义词典：按整词统计，用来修正 jieba 的错切；同时是「保留名单」
/// （优先于内置停用词表，所以内置表误砍的实义词可以在这里找回来）。

abstract class _$WordCloudLexiconList extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表，
/// 打开它会把「雨 / 猫 / 书」这类实义单字一起去掉。

@ProviderFor(WordCloudHideSingleChars)
final wordCloudHideSingleCharsProvider = WordCloudHideSingleCharsProvider._();

/// 是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表，
/// 打开它会把「雨 / 猫 / 书」这类实义单字一起去掉。
final class WordCloudHideSingleCharsProvider
    extends $NotifierProvider<WordCloudHideSingleChars, bool> {
  /// 是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表，
  /// 打开它会把「雨 / 猫 / 书」这类实义单字一起去掉。
  WordCloudHideSingleCharsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordCloudHideSingleCharsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordCloudHideSingleCharsHash();

  @$internal
  @override
  WordCloudHideSingleChars create() => WordCloudHideSingleChars();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$wordCloudHideSingleCharsHash() =>
    r'37d6d4027c10e7e60642f657eff6719a18a4bbb4';

/// 是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表，
/// 打开它会把「雨 / 猫 / 书」这类实义单字一起去掉。

abstract class _$WordCloudHideSingleChars extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
