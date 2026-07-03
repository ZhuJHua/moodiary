// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_key_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 用户密钥（同步加密用）的 Riverpod 入口 —— 读写 [MoodiarySecureKVs.userKey]。
///
/// state 为 `null` 表示未设置；非空字符串为已设置的 key。

@ProviderFor(UserKeyController)
final userKeyControllerProvider = UserKeyControllerProvider._();

/// 用户密钥（同步加密用）的 Riverpod 入口 —— 读写 [MoodiarySecureKVs.userKey]。
///
/// state 为 `null` 表示未设置；非空字符串为已设置的 key。
final class UserKeyControllerProvider
    extends $AsyncNotifierProvider<UserKeyController, String?> {
  /// 用户密钥（同步加密用）的 Riverpod 入口 —— 读写 [MoodiarySecureKVs.userKey]。
  ///
  /// state 为 `null` 表示未设置；非空字符串为已设置的 key。
  UserKeyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userKeyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userKeyControllerHash();

  @$internal
  @override
  UserKeyController create() => UserKeyController();
}

String _$userKeyControllerHash() => r'17ce3d2c2433ab68529d083c07ee7045939f821c';

/// 用户密钥（同步加密用）的 Riverpod 入口 —— 读写 [MoodiarySecureKVs.userKey]。
///
/// state 为 `null` 表示未设置；非空字符串为已设置的 key。

abstract class _$UserKeyController extends $AsyncNotifier<String?> {
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
