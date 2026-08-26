// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
/// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
/// 由纯函数 [buildMediaGroup] 派生，不落 state。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
/// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。

@ProviderFor(MediaDiaries)
final mediaDiariesProvider = MediaDiariesFamily._();

/// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
/// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
/// 由纯函数 [buildMediaGroup] 派生，不落 state。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
/// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。
final class MediaDiariesProvider
    extends $AsyncNotifierProvider<MediaDiaries, List<Diary>> {
  /// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
  /// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
  /// 由纯函数 [buildMediaGroup] 派生，不落 state。
  ///
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
  /// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。
  MediaDiariesProvider._({
    required MediaDiariesFamily super.from,
    required MediaType super.argument,
  }) : super(
         retry: null,
         name: r'mediaDiariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaDiariesHash();

  @override
  String toString() {
    return r'mediaDiariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MediaDiaries create() => MediaDiaries();

  @override
  bool operator ==(Object other) {
    return other is MediaDiariesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaDiariesHash() => r'1d8839f32d6e133583fe5c68866a192ab998a4c3';

/// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
/// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
/// 由纯函数 [buildMediaGroup] 派生，不落 state。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
/// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。

final class MediaDiariesFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaDiaries,
          AsyncValue<List<Diary>>,
          List<Diary>,
          FutureOr<List<Diary>>,
          MediaType
        > {
  MediaDiariesFamily._()
    : super(
        retry: null,
        name: r'mediaDiariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
  /// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
  /// 由纯函数 [buildMediaGroup] 派生，不落 state。
  ///
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
  /// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。

  MediaDiariesProvider call({required MediaType type}) =>
      MediaDiariesProvider._(argument: type, from: this);

  @override
  String toString() => r'mediaDiariesProvider';
}

/// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
/// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
/// 由纯函数 [buildMediaGroup] 派生，不落 state。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
/// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。

abstract class _$MediaDiaries extends $AsyncNotifier<List<Diary>> {
  late final _$args = ref.$arg as MediaType;
  MediaType get type => _$args;

  FutureOr<List<Diary>> build({required MediaType type});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Diary>>, List<Diary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Diary>>, List<Diary>>,
              AsyncValue<List<Diary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(type: _$args));
  }
}

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaDiariesProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。

@ProviderFor(MediaCleanupController)
final mediaCleanupControllerProvider = MediaCleanupControllerProvider._();

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaDiariesProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。
final class MediaCleanupControllerProvider
    extends $NotifierProvider<MediaCleanupController, void> {
  /// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
  /// [clean] 只删文件——刷新（失效 [mediaDiariesProvider]）由调用方用自身有效 ref 触发，
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
    r'bfbbdb7b067e2fcaf82d875f3d8ecca9d474d924';

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaDiariesProvider]）由调用方用自身有效 ref 触发，
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
