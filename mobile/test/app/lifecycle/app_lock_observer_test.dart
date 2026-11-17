import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mobile/app/lifecycle/app_lock_observer.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

void main() {
  setUpAll(() {
    router = GoRouter(
      routes: [
        for (final path in [
          DiaryHomeRoute.path,
          NewDiaryRoute.path,
          LockRoute.path,
        ])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
  });

  setUp(() async {
    getIt.pushNewScope(
      init: (gi) {
        gi.registerSingleton<IKVStorage>(MemoryKVStorage());
        gi.registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
      },
    );
    AppLockPin.hasher = (pin) async => r'$argon2-fake';
    await AppLockPin.set('1234');
    MoodiaryKVs.lockNow.set(true);
  });

  tearDown(() async {
    await AppLockPin.clear();
    await getIt.popScope();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    router.go(DiaryHomeRoute.path);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => AppLockObserver(child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pause(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(.resumed);
    await tester.pumpAndSettle();
  }

  int lockMatches() => router.routerDelegate.currentConfiguration.matches
      .where((m) => m.matchedLocation == LockRoute.path)
      .length;

  testWidgets('pushed NewDiaryRoute skips the pause lock', (tester) async {
    await pumpApp(tester);
    router.pushRoute(const NewDiaryRoute());
    await tester.pumpAndSettle();

    await pause(tester);

    expect(lockMatches(), 0);
    expect(find.text(NewDiaryRoute.path), findsOneWidget);
  });

  testWidgets('an existing LockRoute is not locked again', (tester) async {
    await pumpApp(tester);
    router.pushRoute(const LockRoute(lockType: 'pause'));
    await tester.pumpAndSettle();

    await pause(tester);

    expect(lockMatches(), 1);
  });

  testWidgets('home still locks on pause', (tester) async {
    await pumpApp(tester);

    await pause(tester);

    expect(lockMatches(), 1);
  });
}
