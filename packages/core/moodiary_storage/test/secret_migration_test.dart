import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
// 迁移是包内实现细节，不进 barrel（免得 feature 包够得到 clearStore 这类一次性操作）。

import 'support/memory_kv.dart';

void main() {
  late MemorySecureKVStorage secure;
  late MemoryKVSource legacy;

  setUp(() async {
    await getIt.reset();
    secure = MemorySecureKVStorage();
    legacy = MemoryKVSource();
    getIt.registerSingleton<ISecureKVStorage>(secure);
  });

  group('SecretKVMigration', () {
    test('三个键原样搬进 SecureKV', () async {
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';
      legacy.data['qweatherKey'] = 'qw-key';
      legacy.data['tiandituKey'] = 'td-key';

      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.qweatherKey.get(), 'qw-key');
      expect(await MoodiarySecureKVs.tiandituKey.get(), 'td-key');
      // PIN 也是原样 —— 哈希推迟到首次解锁，见 AppLockPin.verify。
      expect(await MoodiarySecureKVs.password.get(), '1234');
    });

    test('旧仓库里没有的键不写空值进去', () async {
      legacy.data['qweatherKey'] = 'qw-key';

      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), isNull);
      expect(await MoodiarySecureKVs.tiandituKey.get(), isNull);
    });

    /// 整轮共用 `__migrated_from_prefs` 一个标记，失败必须上抛让调用方整轮跳过 ——
    /// 吞掉的话应用锁会变成「开着但没有密码」，用户直接进不去。
    test('钥匙串写失败时上抛，不吞', () async {
      secure.failingKeys.add('password');
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      expect(() => SecretKVMigration.run(legacy), throwsStateError);
    });

    /// 2.8.0 起「应用锁开没开」= 有没有凭据，旧的 lock 开关已删。所以关着锁的用户
    /// 那把残留 PIN 一定不能搬 —— 搬了等于替他把锁打开，而他可能早忘了那四位数。
    test('旧的 lock 是关的 → 不搬 PIN，但另外两个照搬', () async {
      legacy.data['lock'] = false;
      legacy.data['password'] = '1234';
      legacy.data['qweatherKey'] = 'qw-key';

      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), isNull);
      expect(await MoodiarySecureKVs.qweatherKey.get(), 'qw-key');
    });

    test('旧仓库压根没有 lock 这个键 → 同样不搬 PIN', () async {
      legacy.data['password'] = '1234';

      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), isNull);
    });

    /// 机密排在明文之前搬，所以失败时旧仓库还在、MMKV 还没被写过，重跑是干净的。
    test('重跑幂等', () async {
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      await SecretKVMigration.run(legacy);
      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), '1234');
    });
  });
}
