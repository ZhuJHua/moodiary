library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/calendar/calendar_page.dart';
import 'src/presentation/category/category_manager_page.dart';
import 'src/presentation/detail/diary_page.dart';
import 'src/presentation/graph/diary_ego_graph_page.dart';
import 'src/presentation/graph/diary_graph_page.dart';
import 'src/presentation/manager/diary_manager_page.dart';
import 'src/presentation/map/map_page.dart';
import 'src/presentation/place/place_manager_page.dart';
import 'src/presentation/recycle/recycle_page.dart';
import 'src/presentation/search/search_page.dart';

export 'src/application/diary_filter.dart'
    show DiaryFilter, homeDiaryFilterProvider, DiaryFilterNotifier;
export 'src/application/diary_selection.dart'
    show diarySelectionProvider, DiarySelectionNotifier;
export 'src/presentation/diary_select_page.dart' show DiarySelectPage;
export 'src/presentation/widget/category_drawer.dart' show CategoryDrawer;
export 'src/presentation/widget/feed_view.dart' show DiaryFeedView;
export 'src/presentation/widget/timeline_view.dart' show DiaryTimelineView;
export 'src/presentation/widget/view_mode_sheet.dart' show ViewModeSheet;

List<RouteBase> diaryRoutes() => [
  GoRoute(
    path: NewDiaryRoute.path,
    builder: (_, state) => DiaryPage.fromRoute(state),
  ),
  GoRoute(
    path: DiaryRoute.path,
    builder: (_, state) => DiaryPage.fromRoute(state),
  ),
  GoRoute(
    path: DiarySearchRoute.path,
    builder: (_, _) => const DiarySearchPage(),
  ),
  GoRoute(path: RecycleRoute.path, builder: (_, _) => const RecyclePage()),
  GoRoute(
    path: CategoryManagerRoute.path,
    builder: (_, _) => const CategoryManagerPage(),
  ),
  GoRoute(
    path: PlaceManagerRoute.path,
    builder: (_, _) => const PlaceManagerPage(),
  ),
  GoRoute(path: MapRoute.path, builder: (_, _) => const MapPage()),
  GoRoute(path: CalendarRoute.path, builder: (_, _) => const CalendarPage()),
  GoRoute(
    path: DiaryManagerRoute.path,
    builder: (_, _) => const DiaryManagerPage(),
  ),
  GoRoute(
    path: DiaryGraphRoute.path,
    builder: (_, state) => state.params['diary_id'] == null
        ? const DiaryGraphPage()
        : DiaryEgoGraphPage.fromRoute(state),
  ),
];
