import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mobile/app/lifecycle/reminder_navigation.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:mui/mui.dart';

class _ReminderService extends Fake implements ReminderService {
  final events = StreamController<void>.broadcast();

  @override
  bool launchedFromNotification = true;

  @override
  ReminderTapAction tapAction = ReminderTapAction.openApp;

  @override
  Stream<void> get taps => events.stream;
}

void main() {
  testWidgets('cold and warm taps honor the selected action', (tester) async {
    final service = _ReminderService();
    getIt.registerSingleton<ReminderService>(service);
    router = GoRouter(
      initialLocation: LockRoute.path,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: LockRoute.path,
          builder: (_, _) => const Scaffold(body: Text('locked')),
        ),
        GoRoute(
          path: NewDiaryRoute.path,
          builder: (_, state) =>
              Scaffold(body: Text('new diary: ${state.params['edit']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(service.events.close);
    addTearDown(getIt.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => ReminderNavigation(child: child!),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(find.text('new diary: true'), findsNothing);
    expect(service.launchedFromNotification, isFalse);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    service.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('new diary: true'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.tapAction = ReminderTapAction.newDiary;
    service.launchedFromNotification = true;
    router.go(LockRoute.path);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => ReminderNavigation(child: child!),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(service.launchedFromNotification, isTrue);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('new diary: true'), findsOneWidget);
    expect(service.launchedFromNotification, isFalse);
    router.pop();
    await tester.pumpAndSettle();
    service.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('new diary: true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
