import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'package:moodiary/feature/lock/presentation/lock_page.dart';
import 'package:moodiary/feature/lock/presentation/start_page.dart';

List<RouteBase> lockRoutes() => [
  GoRoute(
    path: LockRoute.path,
    builder: (context, state) {
      final route = LockRoute.fromState(state);
      return LockPage(lockType: route.lockType);
    },
  ),
  GoRoute(path: StartRoute.path, builder: (_, _) => const StartPage()),
];
