library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/media_page.dart';

export 'src/media_controller.dart';
export 'src/media_page.dart';
export 'src/media_video_viewer.dart';

List<RouteBase> mediaRoutes() => [
  GoRoute(path: MediaRoute.path, builder: (_, _) => const MediaPage()),
];
