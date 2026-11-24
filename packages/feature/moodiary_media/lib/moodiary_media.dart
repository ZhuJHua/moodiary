library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/media_detail_page.dart';
import 'src/media_page.dart';

export 'src/media_controller.dart';
export 'src/media_page.dart';
export 'src/media_video_viewer.dart';

List<RouteBase> mediaRoutes() => [
  GoRoute(
    path: MediaDetailRoute.path,
    builder: (_, state) => MediaDetailPage.fromRoute(state),
  ),
  GoRoute(
    path: MediaRoute.path,
    builder: (_, state) => MediaPage.fromRoute(state),
  ),
];
