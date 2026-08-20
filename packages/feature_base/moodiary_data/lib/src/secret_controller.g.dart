// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
/// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
/// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
/// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
///
/// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
/// 不必绕这里。

@ProviderFor(secretKv)
final secretKvProvider = SecretKvFamily._();

/// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
/// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
/// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
/// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
///
/// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
/// 不必绕这里。

final class SecretKvProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
  /// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
  /// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
  /// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
  ///
  /// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
  /// 不必绕这里。
  SecretKvProvider._({
    required SecretKvFamily super.from,
    required MoodiarySecureKVs super.argument,
  }) : super(
         retry: null,
         name: r'secretKvProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$secretKvHash();

  @override
  String toString() {
    return r'secretKvProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as MoodiarySecureKVs;
    return secretKv(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SecretKvProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$secretKvHash() => r'85633856dc8532ffe44ed1cdb6efc9d74d75c01e';

/// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
/// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
/// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
/// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
///
/// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
/// 不必绕这里。

final class SecretKvFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, MoodiarySecureKVs> {
  SecretKvFamily._()
    : super(
        retry: null,
        name: r'secretKvProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
  /// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
  /// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
  /// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
  ///
  /// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
  /// 不必绕这里。

  SecretKvProvider call(MoodiarySecureKVs key) =>
      SecretKvProvider._(argument: key, from: this);

  @override
  String toString() => r'secretKvProvider';
}
