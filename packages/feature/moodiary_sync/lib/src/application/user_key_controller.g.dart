// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_key_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同步数据密钥（DEK）的 Riverpod 视图 —— 只读；写入走 [SyncKeyManager]
/// （开启 / 改密码 / 关闭的编排在 user_key_change_flow），改完 invalidate 本 provider。
///
/// state 为 `null` 表示未开启加密；非空为 DEK 的 base64（供二维码跨设备传输）。

@ProviderFor(SyncDekController)
final syncDekControllerProvider = SyncDekControllerProvider._();

/// 同步数据密钥（DEK）的 Riverpod 视图 —— 只读；写入走 [SyncKeyManager]
/// （开启 / 改密码 / 关闭的编排在 user_key_change_flow），改完 invalidate 本 provider。
///
/// state 为 `null` 表示未开启加密；非空为 DEK 的 base64（供二维码跨设备传输）。
final class SyncDekControllerProvider
    extends $AsyncNotifierProvider<SyncDekController, String?> {
  /// 同步数据密钥（DEK）的 Riverpod 视图 —— 只读；写入走 [SyncKeyManager]
  /// （开启 / 改密码 / 关闭的编排在 user_key_change_flow），改完 invalidate 本 provider。
  ///
  /// state 为 `null` 表示未开启加密；非空为 DEK 的 base64（供二维码跨设备传输）。
  SyncDekControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDekControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDekControllerHash();

  @$internal
  @override
  SyncDekController create() => SyncDekController();
}

String _$syncDekControllerHash() => r'61d3e7d5b007b647ee005c96c0d566d772ac4c12';

/// 同步数据密钥（DEK）的 Riverpod 视图 —— 只读；写入走 [SyncKeyManager]
/// （开启 / 改密码 / 关闭的编排在 user_key_change_flow），改完 invalidate 本 provider。
///
/// state 为 `null` 表示未开启加密；非空为 DEK 的 base64（供二维码跨设备传输）。

abstract class _$SyncDekController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
