import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'support/memory_kv.dart';

void main() {
  late MemorySecureKVStorage secure;

  setUp(() async {
    await getIt.reset();
    secure = MemorySecureKVStorage();
    getIt.registerSingleton<ISecureKVStorage>(secure);
    // 宿主没有 Rust FFI，用可辨认的假哈希顶上（形状与 Argon2 的 PHC 串一致）。
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

  /// 「没设过密码」绝不能等价于「任何输入都放行」—— 那是直接绕过应用锁。
  test('没设过密码时任何输入都不通过', () async {
    expect(await AppLockPin.verify(''), isFalse);
    expect(await AppLockPin.verify('1234'), isFalse);
  });

  test('清除后校验不通过', () async {
    await AppLockPin.set('1234');
    await AppLockPin.clear();

    expect(await AppLockPin.verify('1234'), isFalse);
  });

  /// 「应用锁开没开」是「有没有凭据」的派生态，没有第二个开关能与它分叉。
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

    /// 读不出凭据按未开启处理。永久锁死的代价远大于此 —— 应用锁本就不保护静态数据，
    /// 能拿到 App 文件的人直接读 Isar 就行，它挡的只是「顺手打开」。
    test('钥匙串读失败时按未开启处理，不把用户挡在门外', () async {
      await AppLockPin.set('1234');
      expect(AppLockPin.enabled.value, isTrue);

      secure.failingReads.add(MoodiarySecureKVs.password.name);
      await AppLockPin.load();

      expect(AppLockPin.enabled.value, isFalse);
    });
  });

  /// 搬迁把 2.7.3 的 PIN 原样挪进钥匙串（那样 KV 初始化不必等 Rust 桥），
  /// 哈希推迟到这里 —— 所以这条分支是搬迁后每个开锁用户的必经之路，不是历史包袱。
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

  /// Rust 侧对任何解析不出的 PHC 串都返回 Err；抛到解锁页会让键盘僵在四个圆点上，
  /// 没有提示、不计次、不进冷却。当作不匹配处理。
  test('校验原语抛异常时当作不匹配，不上抛', () async {
    await AppLockPin.set('1234');
    AppLockPin.verifier = (hash, pin) async => throw StateError('bad hash');

    expect(await AppLockPin.verify('1234'), isFalse);
  });
}
