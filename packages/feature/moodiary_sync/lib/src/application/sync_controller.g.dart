// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同步 controller：状态机 idle → syncing → idle / error。不持有具体 [SyncBackend]，
/// 调用方在 [push]/[pull] 时显式传入，同一 controller 可服务 JSON 备份与 WebDAV。
///
/// keepAlive：同步是后台过程，不随页面销毁 —— 否则 autoDispose 会在页面关闭时销毁
/// notifier，同步完成后的 state 赋值直接抛错。

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// 同步 controller：状态机 idle → syncing → idle / error。不持有具体 [SyncBackend]，
/// 调用方在 [push]/[pull] 时显式传入，同一 controller 可服务 JSON 备份与 WebDAV。
///
/// keepAlive：同步是后台过程，不随页面销毁 —— 否则 autoDispose 会在页面关闭时销毁
/// notifier，同步完成后的 state 赋值直接抛错。
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncState> {
  /// 同步 controller：状态机 idle → syncing → idle / error。不持有具体 [SyncBackend]，
  /// 调用方在 [push]/[pull] 时显式传入，同一 controller 可服务 JSON 备份与 WebDAV。
  ///
  /// keepAlive：同步是后台过程，不随页面销毁 —— 否则 autoDispose 会在页面关闭时销毁
  /// notifier，同步完成后的 state 赋值直接抛错。
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

String _$syncControllerHash() => r'834485372b4b82cb1a809057c0a53b8bc7f0372e';

/// 同步 controller：状态机 idle → syncing → idle / error。不持有具体 [SyncBackend]，
/// 调用方在 [push]/[pull] 时显式传入，同一 controller 可服务 JSON 备份与 WebDAV。
///
/// keepAlive：同步是后台过程，不随页面销毁 —— 否则 autoDispose 会在页面关闭时销毁
/// notifier，同步完成后的 state 赋值直接抛错。

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
