import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'package:moodiary_storage/testing.dart';

void main() {
  late MemorySecureKVStorage secure;
  late MemoryKVSource legacy;

  setUp(() {
    secure = MemorySecureKVStorage();
    legacy = MemoryKVSource();
  });

  group('SecretKVMigration', () {
    test('三个键原样搬进 SecureKV', () async {
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';
      legacy.data['qweatherKey'] = 'qw-key';
      legacy.data['tiandituKey'] = 'td-key';

      await SecretKVMigration.run(legacy, secure);

      expect(await secure.get('qweatherKey'), 'qw-key');
      expect(await secure.get('tiandituKey'), 'td-key');
      expect(await secure.get('password'), '1234');
    });

    test('旧仓库里没有的键不写空值进去', () async {
      legacy.data['qweatherKey'] = 'qw-key';

      await SecretKVMigration.run(legacy, secure);

      expect(await secure.get('password'), isNull);
      expect(await secure.get('tiandituKey'), isNull);
    });

    test('钥匙串写失败时上抛，不吞', () async {
      secure.failingKeys.add('password');
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      expect(() => SecretKVMigration.run(legacy, secure), throwsStateError);
    });

    test('旧的 lock 是关的 → 不搬 PIN，但另外两个照搬', () async {
      legacy.data['lock'] = false;
      legacy.data['password'] = '1234';
      legacy.data['qweatherKey'] = 'qw-key';

      await SecretKVMigration.run(legacy, secure);

      expect(await secure.get('password'), isNull);
      expect(await secure.get('qweatherKey'), 'qw-key');
    });

    test('重跑幂等', () async {
      legacy.data['lock'] = true;
      legacy.data['password'] = '1234';

      await SecretKVMigration.run(legacy, secure);
      await SecretKVMigration.run(legacy, secure);

      expect(await secure.get('password'), '1234');
    });
  });
}
