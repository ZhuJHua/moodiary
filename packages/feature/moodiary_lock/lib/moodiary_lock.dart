library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/lock_page.dart';

export 'src/presentation/lock_page.dart';
export 'src/presentation/widget/app_lock_tile.dart';

List<RouteBase> lockRoutes() => [
  GoRoute(
    path: LockRoute.path,
    builder: (_, state) => LockPage.fromRoute(state),
  ),
];
