import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/share_page.dart';

List<RouteBase> shareRoutes() => [
  MoodiaryGoRoute(
    path: ShareRoute.path,
    builder: (context, state) {
      final route = ShareRoute.fromState(state);
      return SharePage(diaryId: route.diaryId);
    },
  ),
];
