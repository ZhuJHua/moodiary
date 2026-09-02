// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
/// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
/// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
/// 时不插，翻页自然带来）。

@ProviderFor(MediaItems)
final mediaItemsProvider = MediaItemsFamily._();

/// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
/// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
/// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
/// 时不插，翻页自然带来）。
final class MediaItemsProvider
    extends $AsyncNotifierProvider<MediaItems, List<MediaItem>> {
  /// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
  /// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
  ///
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
  /// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
  /// 时不插，翻页自然带来）。
  MediaItemsProvider._({
    required MediaItemsFamily super.from,
    required MediaType super.argument,
  }) : super(
         retry: null,
         name: r'mediaItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaItemsHash();

  @override
  String toString() {
    return r'mediaItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MediaItems create() => MediaItems();

  @override
  bool operator ==(Object other) {
    return other is MediaItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaItemsHash() => r'4ca954e78e18ff9672831c24aa3dcfe5ca2cb00f';

/// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
/// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
/// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
/// 时不插，翻页自然带来）。

final class MediaItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaItems,
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>,
          MediaType
        > {
  MediaItemsFamily._()
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
  /// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
  ///
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
  /// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
  /// 时不插，翻页自然带来）。

  MediaItemsProvider call({required MediaType type}) =>
      MediaItemsProvider._(argument: type, from: this);

  @override
  String toString() => r'mediaItemsProvider';
}

/// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
/// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
/// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
/// 时不插，翻页自然带来）。

abstract class _$MediaItems extends $AsyncNotifier<List<MediaItem>> {
  late final _$args = ref.$arg as MediaType;
  MediaType get type => _$args;

  FutureOr<List<MediaItem>> build({required MediaType type});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(type: _$args));
  }
}

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaItemsProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。

@ProviderFor(MediaCleanupController)
final mediaCleanupControllerProvider = MediaCleanupControllerProvider._();

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaItemsProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。
final class MediaCleanupControllerProvider
    extends $NotifierProvider<MediaCleanupController, void> {
  /// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
  /// [clean] 只删文件——刷新（失效 [mediaItemsProvider]）由调用方用自身有效 ref 触发，
  /// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。
  MediaCleanupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaCleanupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaCleanupControllerHash();

  @$internal
  @override
  MediaCleanupController create() => MediaCleanupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$mediaCleanupControllerHash() =>
    r'66acabaa965b5a26227ee93becb42cd755f71715';

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaItemsProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。

abstract class _$MediaCleanupController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
