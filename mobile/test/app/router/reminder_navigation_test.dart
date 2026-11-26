import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/lifecycle/reminder_navigation.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:mui/mui.dart';

class _ReminderService extends Fake implements ReminderService {
  final events = StreamController<void>.broadcast();

  int pending = 0;

  void tap() {
    pending++;
    events.add(null);
  }

  @override
  bool get launchedFromNotification => pending > 0;

  @override
  bool consumeTap() {
    if (pending == 0) return false;
    pending--;
    return true;
  }

  @override
  ReminderTapAction tapAction = ReminderTapAction.openApp;

  @override
  Stream<void> get taps => events.stream;
}

void main() {
  late GoRouter router;
  late _ReminderService service;
  setUp(() {
    service = _ReminderService();
    addTearDown(service.events.close);
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
        GoRoute(
          path: '/details',
          builder: (_, _) => const Scaffold(body: Text('details')),
        ),
      ],
    );
    addTearDown(router.dispose);
  });

  Widget app() => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      appRouterProvider.overrideWithValue(router),
      reminderServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (_, child) => ReminderNavigation(child: child!),
    ),
  );

  testWidgets('cold and warm taps honor the selected action', (tester) async {
    service.pending = 1;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(find.text('new diary: true'), findsNothing);
    expect(service.launchedFromNotification, isTrue);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(service.launchedFromNotification, isFalse);
    service.tap();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('new diary: true'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.tapAction = ReminderTapAction.newDiary;
    service.pending = 1;
    router.go(LockRoute.path);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(service.launchedFromNotification, isTrue);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('new diary: true'), findsOneWidget);
    expect(service.launchedFromNotification, isFalse);
    router.pop();
    await tester.pumpAndSettle();
    service.tap();
    await tester.pumpAndSettle();
    expect(find.text('new diary: true'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    unawaited(router.push(LockRoute.path));
    await tester.pumpAndSettle();
    service.tap();
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(find.text('new diary: true'), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('new diary: true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('warm taps reuse an editor anywhere in the stack', (
    tester,
  ) async {
    service.tapAction = ReminderTapAction.newDiary;
    router.go('/');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    unawaited(router.pushRoute(const NewDiaryRoute()));
    await tester.pumpAndSettle();
    for (final covered in [false, true]) {
      if (covered) {
        unawaited(router.push('/details'));
        await tester.pumpAndSettle();
      }
      service.tap();
      service.tap();
      await tester.pumpAndSettle();
      expect(service.launchedFromNotification, isFalse);
      expect(
        router.routerDelegate.currentConfiguration.matches.where(
          (match) => match.matchedLocation == NewDiaryRoute.path,
        ),
        hasLength(1),
      );
      expect(find.text('new diary: true', skipOffstage: false), findsOneWidget);
      if (covered) {
        expect(find.text('details'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }
    }
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(service.launchedFromNotification, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
