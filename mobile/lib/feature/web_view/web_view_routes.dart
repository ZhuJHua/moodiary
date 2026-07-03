import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'package:moodiary/feature/web_view/presentation/web_view_page.dart';

List<RouteBase> webViewRoutes() => [
  GoRoute(
    path: WebViewRoute.path,
    builder: (context, state) {
      final route = WebViewRoute.fromState(state);
      return WebViewPage(url: route.url, title: route.title);
    },
  ),
];
