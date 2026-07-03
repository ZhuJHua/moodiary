import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'package:moodiary/feature/user/presentation/login_page.dart';
import 'package:moodiary/feature/user/presentation/user_page.dart';

List<RouteBase> userRoutes() => [
  GoRoute(path: UserRoute.path, builder: (_, _) => const UserPage()),
  GoRoute(path: LoginRoute.path, builder: (_, _) => const LoginPage()),
];
