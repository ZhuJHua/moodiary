// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同步状态的 Riverpod 桥：idle → syncing → success / partial / error。执行本身在
/// [SyncRunner]；这里只是把它的 [SyncStatus] 折成 widget 好消费的五态。
///
/// 自动同步（watcher 经 runner 跑的）只镜像 **running**：图标要转、弹窗要显示进度、
/// 设置页要能停；但它的结果不进 success / error——那会让设置页每 30 秒弹一次
/// 「已是最新」。自动同步的结果由弹窗直接读 `runner.status.last`。
///
/// keepAlive：同步是后台过程，不随页面销毁。

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// 同步状态的 Riverpod 桥：idle → syncing → success / partial / error。执行本身在
/// [SyncRunner]；这里只是把它的 [SyncStatus] 折成 widget 好消费的五态。
///
/// 自动同步（watcher 经 runner 跑的）只镜像 **running**：图标要转、弹窗要显示进度、
/// 设置页要能停；但它的结果不进 success / error——那会让设置页每 30 秒弹一次
/// 「已是最新」。自动同步的结果由弹窗直接读 `runner.status.last`。
///
/// keepAlive：同步是后台过程，不随页面销毁。
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncState> {
  /// 同步状态的 Riverpod 桥：idle → syncing → success / partial / error。执行本身在
  /// [SyncRunner]；这里只是把它的 [SyncStatus] 折成 widget 好消费的五态。
  ///
  /// 自动同步（watcher 经 runner 跑的）只镜像 **running**：图标要转、弹窗要显示进度、
  /// 设置页要能停；但它的结果不进 success / error——那会让设置页每 30 秒弹一次
  /// 「已是最新」。自动同步的结果由弹窗直接读 `runner.status.last`。
  ///
  /// keepAlive：同步是后台过程，不随页面销毁。
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncControllerHash() => r'87b2dfd71f2bc7a835cd2bbcd6f7507193f3d2ce';

/// 同步状态的 Riverpod 桥：idle → syncing → success / partial / error。执行本身在
/// [SyncRunner]；这里只是把它的 [SyncStatus] 折成 widget 好消费的五态。
///
/// 自动同步（watcher 经 runner 跑的）只镜像 **running**：图标要转、弹窗要显示进度、
/// 设置页要能停；但它的结果不进 success / error——那会让设置页每 30 秒弹一次
/// 「已是最新」。自动同步的结果由弹窗直接读 `runner.status.last`。
///
/// keepAlive：同步是后台过程，不随页面销毁。

abstract class _$SyncController extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
