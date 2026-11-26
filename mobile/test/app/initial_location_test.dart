import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    SecureKVStore.installForTesting(MemorySecureKVStorage());
    addTearDown(SecureKVStore.resetForTesting);
    final hasher = AppLockPin.hasher;
    addTearDown(() => AppLockPin.hasher = hasher);
    addTearDown(AppLockPin.clear);
    AppLockPin.hasher = (pin) async => r'$argon2-fake';
  });

  String initialLocation() =>
      ProviderContainer.test(retry: (_, _) => null)
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .path;

  test('设了应用锁：首帧落在锁屏', () async {
    await AppLockPin.set('1234');
    expect(initialLocation(), LockRoute.path);
  });

  test('首次启动也直接进主界面（引导页已下架，首启不再有拦截）', () {
    expect(initialLocation(), DiaryHomeRoute.path);
  });
}
