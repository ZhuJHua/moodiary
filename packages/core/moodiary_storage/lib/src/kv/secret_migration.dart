import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/values/kv.dart';

/// 2.7.3 明文写在旧仓库里、2.8.0 起归 SecureKV 管的三个键。
///
/// 由 [MmkvKVStorage] 的一次性搬迁调用，**和明文键那趟是同一次搬迁的两半**，共用
/// `__migrated_from_prefs` 一个标记：这里抛出去就整轮不置位、旧仓库不删，下次启动重来。
/// 所以本函数不自带标记、不自带重试，也不需要"已有值就不覆盖"——重跑一遍写进去的是
/// 同一份东西。
///
/// **三个键一律原样搬，包括 PIN。** 把 PIN 哈希成 Argon2id 是 `AppLockPin.verify`
/// 头一次比对时就地做的，不在这里 —— 否则 KV 初始化就依赖 Rust 桥先就绪，等于让一次
/// 性迁移的需求永久钉死 `main.dart` 的启动顺序，而那个顺序只有注释守着。
/// 代价是 PIN 在钥匙串里明文待到下次解锁；开着锁的用户下一次启动就是解锁。
final class SecretKVMigration {
  SecretKVMigration._();

  /// 旧键名 → 新条目。这三个键已从 [MoodiaryKVs] 删除，所以左边只能写字面量；
  /// 它们同时必须出现在 `LegacyPrefsKVSource.legacyKeys` 里，否则旧仓库的 allowList
  /// 不覆盖，读出来恒为 null。有闸门守着这条。
  static const Map<String, MoodiarySecureKVs> _moved = {
    'password': MoodiarySecureKVs.password,
    'qweatherKey': MoodiarySecureKVs.qweatherKey,
    'tiandituKey': MoodiarySecureKVs.tiandituKey,
  };

  static Set<String> get movedKeys => _moved.keys.toSet();

  static Future<void> run(IKVSource legacy) async {
    // 2.8.0 起「应用锁开没开」= 有没有凭据（`AppLockPin.enabled`），旧的 `lock` 开关
    // 已删。所以关着锁的用户那把 PIN 一定不能搬 —— 搬了等于替他把锁打开，而他可能
    // 早就忘了那四位数。2.7.x 的关锁流程是 lock=false 与删 password 一起做的，
    // 只有「两次写之间进程被杀」那道窄缝会留下孤儿密码，这里一并挡掉。
    final lockWasOn = legacy.get<bool>('lock') == true;

    for (final MapEntry(key: name, value: target) in _moved.entries) {
      if (target == MoodiarySecureKVs.password && !lockWasOn) continue;
      final value = legacy.get<String>(name);
      if (value == null || value.isEmpty) continue;
      await target.set(value);
    }
  }
}
