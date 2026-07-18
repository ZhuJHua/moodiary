import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/lock_page.dart';
import 'presentation/start_page.dart';

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
