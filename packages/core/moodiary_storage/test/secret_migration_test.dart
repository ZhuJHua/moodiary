import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'package:moodiary_storage/testing.dart';

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
      expect(await MoodiarySecureKVs.password.get(), '1234');
    });

    test('旧仓库里没有的键不写空值进去', () async {
      legacy.data['qweatherKey'] = 'qw-key';

      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), isNull);
      expect(await MoodiarySecureKVs.tiandituKey.get(), isNull);
    });

    test('钥匙串写失败时上抛，不吞', () async {
      secure.failingKeys.add('password');
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      expect(() => SecretKVMigration.run(legacy), throwsStateError);
    });

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

    test('重跑幂等', () async {
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      await SecretKVMigration.run(legacy);
      await SecretKVMigration.run(legacy);

      expect(await MoodiarySecureKVs.password.get(), '1234');
    });
  });
}
