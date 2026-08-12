// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme] / [bumpLocale]，
/// 根 widget `ref.watch` 即刷新根节点的 theme / locale / themeMode。
/// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
/// 且主题 / locale 重建是异步的。

@ProviderFor(AppSettingsController)
final appSettingsControllerProvider = AppSettingsControllerProvider._();

/// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme] / [bumpLocale]，
/// 根 widget `ref.watch` 即刷新根节点的 theme / locale / themeMode。
/// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
/// 且主题 / locale 重建是异步的。
final class AppSettingsControllerProvider
    extends $NotifierProvider<AppSettingsController, AppSettings> {
  /// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme] / [bumpLocale]，
  /// 根 widget `ref.watch` 即刷新根节点的 theme / locale / themeMode。
  /// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
  /// 且主题 / locale 重建是异步的。
  AppSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsControllerHash();

  @$internal
  @override
  AppSettingsController create() => AppSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsControllerHash() =>
    r'86bf07e3cdd604b41411b65b69eac42558487428';

/// 全局应用设置。业务侧改完 KV 后调 [AppSettingsController.bumpTheme] / [bumpLocale]，
/// 根 widget `ref.watch` 即刷新根节点的 theme / locale / themeMode。
/// 收进 provider 而非直接读 KV：主题色 KV 无 defaultValue 不能 `getNotifier()`，
/// 且主题 / locale 重建是异步的。

abstract class _$AppSettingsController extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettings, AppSettings>,
              AppSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
