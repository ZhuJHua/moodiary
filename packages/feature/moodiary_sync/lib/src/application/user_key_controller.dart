import 'package:moodiary_core/moodiary_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_key_controller.g.dart';

/// 用户密钥（同步加密用）的 Riverpod 入口 —— 读写 [MoodiarySecureKVs.userKey]。
///
/// state 为 `null` 表示未设置；非空字符串为已设置的 key。
@riverpod
class UserKeyController extends _$UserKeyController {
  @override
  Future<String?> build() async {
    final v = await MoodiarySecureKVs.userKey.get();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<bool> setKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    await MoodiarySecureKVs.userKey.set(trimmed);
    state = AsyncValue.data(trimmed);
    return true;
  }

  Future<void> clear() async {
    await MoodiarySecureKVs.userKey.remove();
    state = const AsyncValue.data(null);
  }
}
