import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mobile/main.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  setUp(() {
    getIt.pushNewScope(
      init: (gi) {
        gi.registerSingleton<IKVStorage>(MemoryKVStorage());
        gi.registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
      },
    );
    // 宿主单测没有 Rust FFI，换掉 Argon2 原语（同 app_lock_pin_test 的做法）。
    AppLockPin.hasher = (pin) async => r'$argon2-fake';
    // KVNotifier 是进程级静态的，换了存储实例值也会残留——显式复位。
    MoodiaryKVs.firstStart.remove();
  });

  tearDown(() async {
    await AppLockPin.clear();
    await getIt.popScope();
  });

  test('设了应用锁：首帧落在锁屏', () async {
    await AppLockPin.set('1234');
    expect(resolveInitialLocation(), LockRoute.path);
  });

  test('首次启动也直接进主界面（引导页已下架，首启不再有拦截）', () {
    expect(MoodiaryKVs.firstStart.get(), isTrue);
    expect(resolveInitialLocation(), DiaryHomeRoute.path);
  });

  test('非首次启动：进主界面', () {
    MoodiaryKVs.firstStart.set(false);
    expect(resolveInitialLocation(), DiaryHomeRoute.path);
  });
}
