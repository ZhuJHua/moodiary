import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
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

  static final ValueNotifier<bool> _enabled = ValueNotifier(false);

  /// 应用锁是否开启 = **有没有凭据**，没有第二个开关。
  ///
  /// 早先这里是独立的 `MoodiaryKVs.lock`，与凭据分处两个仓库：MMKV 是普通文件，
  /// 恢复备份照样带过来；而钥匙串的密文靠 Keystore 私钥解，那把钥匙不进备份、
  /// 换机恢复或系统升级后可能失效。两者一旦分叉就是「锁开着但没有密码」——
  /// 校验对任何输入都返回 false，用户永久进不去自己的日记，只能卸载重装。
  ///
  /// 现在读不出凭据就是「没开锁」（fail-open）。代价很小：应用锁从来没保护静态数据，
  /// 能拿到 App 文件的人本就能直接读 Isar，它挡的只是「捡到你解锁的手机的人顺手打开」。
  /// 拿永久锁死换这点不划算。
  ///
  /// 同步读是给路由与生命周期回调用的（SecureKV 是异步的），进程内一份，
  /// 由 [load] 在启动时装载、[set] / [clear] 维护 —— 不落盘，所以不会再分叉。
  static ValueListenable<bool> get enabled => _enabled;

  /// 在 SecureKV 就绪后、决定初始路由之前调一次。
  static Future<void> load() async {
    final stored = await _read();
    _enabled.value = stored != null && stored.isNotEmpty;
  }

  static Future<void> set(String pin) async {
    await MoodiarySecureKVs.password.set(await hasher(pin));
    _enabled.value = true;
  }

  static Future<void> clear() async {
    await MoodiarySecureKVs.password.remove();
    _enabled.value = false;
  }

  /// 读凭据。读失败（设备锁定、Keystore 损坏）与「没设过」一样按 null 处理 ——
  /// 见 [enabled] 上关于 fail-open 的取舍。
  static Future<String?> _read() async {
    try {
      return await MoodiarySecureKVs.password.get();
    } catch (e, s) {
      logger.e('应用锁：凭据读取失败，按未开启处理', error: e, stackTrace: s);
      return null;
    }
  }

  /// 校验 PIN。没设过密码时恒为 false —— 别让「没有密码」变成「任何输入都放行」。
  ///
  /// **一律不抛。** [isHashed] 只看 `$argon2` 前缀，截断 / 损坏但仍带前缀的值会让
  /// Rust 侧的 `PasswordHash::new` 抛「Invalid hash format」；调用方是解锁页四位输满
  /// 后由 `Future.delayed` 触发的回调，抛出去没人接，键盘会僵在四个圆点上：
  /// 没有错误提示、不计次、也不进冷却。当作「不匹配」处理，至少走的是正常的失败路径。
  static Future<bool> verify(String pin) async {
    try {
      final stored = await _read();
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
