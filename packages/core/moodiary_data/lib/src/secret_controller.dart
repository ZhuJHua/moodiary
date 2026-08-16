import 'package:moodiary_core/moodiary_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secret_controller.g.dart';

/// [MoodiarySecureKVs] 的读侧视图。SecureKV 读是异步的（每次都是一次真正的
/// 钥匙串 / Keystore 调用），widget 里取值走这个 provider；
/// **写完必须 `ref.invalidate(secretKvProvider(key))`** —— SecureKV 没有
/// [KVNotifier] 那套通知机制，不 invalidate 界面不会刷新。
///
/// 事件回调里（校验 PIN、发请求前取 API Key）直接 `await key.get()` 即可，
/// 不必绕这里。
@riverpod
Future<String?> secretKv(Ref ref, MoodiarySecureKVs key) => key.get();
