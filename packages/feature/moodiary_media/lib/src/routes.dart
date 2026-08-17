import 'package:moodiary_media/src/media_page.dart';
import 'package:moodiary_router/moodiary_router.dart';

List<RouteBase> mediaRoutes() => [
  MoodiaryGoRoute(path: MediaRoute.path, builder: (_, _) => const MediaPage()),
];
