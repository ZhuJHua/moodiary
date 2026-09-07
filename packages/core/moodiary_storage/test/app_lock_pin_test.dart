import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'package:moodiary_storage/testing.dart';

void main() {
  late MemorySecureKVStorage secure;
  late MemoryKVStorage kv;

  setUp(() async {
    await getIt.reset();
    secure = MemorySecureKVStorage();
    kv = MemoryKVStorage();
    getIt.registerSingleton<ISecureKVStorage>(secure);
    getIt.registerSingleton<IKVStorage>(kv);
    AppLockPin.hasher = (pin) async => r'$argon2id$fake$' + pin;
    AppLockPin.verifier = (hash, pin) async => hash == r'$argon2id$fake$' + pin;
  });

  String? stored() => secure.data[MoodiarySecureKVs.password.name];

  test('存进去的不是 PIN 原文', () async {
    await AppLockPin.set('1234');

    expect(stored(), isNot('1234'));
    expect(AppLockPin.isHashed(stored()!), isTrue);
  });

  test('对的 PIN 通过，错的不通过', () async {
    await AppLockPin.set('1234');

    expect(await AppLockPin.verify('1234'), isTrue);
    expect(await AppLockPin.verify('4321'), isFalse);
  });

  test('没设过密码时任何输入都不通过', () async {
    expect(await AppLockPin.verify(''), isFalse);
    expect(await AppLockPin.verify('1234'), isFalse);
  });

  test('清除后校验不通过', () async {
    await AppLockPin.set('1234');
    await AppLockPin.clear();

    expect(await AppLockPin.verify('1234'), isFalse);
  });

  group('enabled', () {
    test('跟着凭据的有无走', () async {
      await AppLockPin.load();
      expect(AppLockPin.enabled.value, isFalse);

      await AppLockPin.set('1234');
      expect(AppLockPin.enabled.value, isTrue);

      await AppLockPin.clear();
      expect(AppLockPin.enabled.value, isFalse);
    });

    test('load 能从已有凭据恢复（冷启动路径）', () async {
      secure.data[MoodiarySecureKVs.password.name] = r'$argon2id$fake$1234';

      await AppLockPin.load();

      expect(AppLockPin.enabled.value, isTrue);
    });

    test('钥匙串读失败时按未开启处理，不把用户挡在门外', () async {
      await AppLockPin.set('1234');
      expect(AppLockPin.enabled.value, isTrue);

      secure.failingReads.add(MoodiarySecureKVs.password.name);
      kv.data.remove(MoodiaryKVs.appLockHint.name);
      await AppLockPin.load();

      expect(AppLockPin.enabled.value, isFalse);
      expect(kv.data.containsKey(MoodiaryKVs.appLockHint.name), isFalse);
    });
  });

  group('appLockHint', () {
    Object? hint() => kv.data[MoodiaryKVs.appLockHint.name];

    test('false → 不读钥匙串（有凭据也按无锁，这是 fail-open 那一侧）', () async {
      secure.data[MoodiarySecureKVs.password.name] = r'$argon2id$fake$1234';
      kv.set<bool>(MoodiaryKVs.appLockHint.name, false);

      await AppLockPin.load();

      expect(AppLockPin.enabled.value, isFalse);
    });

    test('缺失 → 读钥匙串并按结果回写', () async {
      await AppLockPin.load();
      expect(AppLockPin.enabled.value, isFalse);
      expect(hint(), isFalse);

      secure.data[MoodiarySecureKVs.password.name] = r'$argon2id$fake$1234';
      kv.data.remove(MoodiaryKVs.appLockHint.name);
      await AppLockPin.load();
      expect(AppLockPin.enabled.value, isTrue);
      expect(hint(), isTrue);
    });

    test('true 而钥匙串无凭据 → 按未开启并回写 false，不会锁死', () async {
      kv.set<bool>(MoodiaryKVs.appLockHint.name, true);

      await AppLockPin.load();

      expect(AppLockPin.enabled.value, isFalse);
      expect(hint(), isFalse);
    });

    test('set / clear 维护提示位', () async {
      await AppLockPin.set('1234');
      expect(hint(), isTrue);

      await AppLockPin.clear();
      expect(hint(), isFalse);
    });
  });

  group('2.7.3 搬过来的明文原件', () {
    test('比对通过并就地升级成哈希', () async {
      secure.data[MoodiarySecureKVs.password.name] = '1234';

      expect(await AppLockPin.verify('1234'), isTrue);

      expect(AppLockPin.isHashed(stored()!), isTrue);
      expect(await AppLockPin.verify('1234'), isTrue);
    });

    test('比对不过则原样留着，不误升级成错的哈希', () async {
      secure.data[MoodiarySecureKVs.password.name] = '1234';

      expect(await AppLockPin.verify('4321'), isFalse);
      expect(stored(), '1234');
    });
  });

  test('校验原语抛异常时当作不匹配，不上抛', () async {
    await AppLockPin.set('1234');
    AppLockPin.verifier = (hash, pin) async => throw StateError('bad hash');

    expect(await AppLockPin.verify('1234'), isFalse);
  });
}
