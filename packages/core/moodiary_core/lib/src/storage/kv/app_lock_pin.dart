import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_core/src/app_logger.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;

/// 应用锁 PIN 的编解码。存进 [MoodiarySecureKVs.password] 的是 **Argon2id 的 PHC
/// 字符串**（`$argon2id$v=19$m=...`，盐由 Rust 侧随机生成并写在串里），不是 PIN 原文。
/// 唯一的例外是 2.7.3 搬过来还没解锁过的那份明文，[verify] 头一次比对通过就地升级。
///
/// 钥匙串本身已经把它加密了 —— 多这一层是因为加密可逆而哈希不可逆：越过钥匙串的
/// 人（拿到 iCloud 加密备份并知道备份密码、越狱设备…）解出来的只能是一串指纹。
/// 四位 PIN 只有一万种组合，慢 KDF 也拦不住有心人爆破，**这一层真正防的是 PIN 复用**
/// ——很多人的应用锁 PIN 和手机解锁 PIN 是同一个。
final class AppLockPin {
  AppLockPin._();

  /// 可注入的原语：宿主单测没有 Rust FFI（同 `SyncKeyManager` 的做法）。
  @visibleForTesting
  static Future<String> Function(String pin) hasher = _rustHash;
  @visibleForTesting
  static Future<bool> Function(String hash, String pin) verifier = _rustVerify;

  static Future<String> _rustHash(String pin) =>
      rust.Argon2.hash(password: pin);

  static Future<bool> _rustVerify(String hash, String pin) =>
      rust.Argon2.verify(hash: hash, password: pin);

  /// Argon2 的 PHC 串一律以 `$argon2` 开头；不是这个形状的就是 2.7.3 的明文原件。
  static bool isHashed(String stored) => stored.startsWith(r'$argon2');

  static Future<void> set(String pin) async =>
      MoodiarySecureKVs.password.set(await hasher(pin));

  static Future<void> clear() => MoodiarySecureKVs.password.remove();

  /// 校验 PIN。没设过密码时恒为 false —— 别让「没有密码」变成「任何输入都放行」。
  ///
  /// **一律不抛。** [isHashed] 只看 `$argon2` 前缀，截断 / 损坏但仍带前缀的值会让
  /// Rust 侧的 `PasswordHash::new` 抛「Invalid hash format」；调用方是解锁页四位输满
  /// 后由 `Future.delayed` 触发的回调，抛出去没人接，键盘会僵在四个圆点上：
  /// 没有错误提示、不计次、也不进冷却。当作「不匹配」处理，至少走的是正常的失败路径。
  static Future<bool> verify(String pin) async {
    try {
      final stored = await MoodiarySecureKVs.password.get();
      if (stored == null || stored.isEmpty) return false;
      if (!isHashed(stored)) {
        // 2.7.3 的明文原件：搬迁只把它原样挪进钥匙串，哈希推迟到这里做。
        // 这样 KV 初始化不必等 Rust 桥就绪 —— 见 `SecretKVMigration`。
        if (stored != pin) return false;
        await set(pin);
        return true;
      }
      return await verifier(stored, pin);
    } catch (e, s) {
      logger.e('应用锁：校验 PIN 失败', error: e, stackTrace: s);
      return false;
    }
  }
}
