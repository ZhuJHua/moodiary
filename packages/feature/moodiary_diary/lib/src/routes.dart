import 'package:moodiary_diary/src/presentation/category/category_manager_page.dart';
import 'package:moodiary_diary/src/presentation/detail/diary_page.dart'
    show DiaryPage;
import 'package:moodiary_diary/src/presentation/graph/diary_ego_graph_page.dart';
import 'package:moodiary_diary/src/presentation/graph/diary_graph_page.dart';
import 'package:moodiary_diary/src/presentation/manager/diary_manager_page.dart';
import 'package:moodiary_diary/src/presentation/map/map_page.dart';
import 'package:moodiary_diary/src/presentation/recycle/recycle_page.dart';
import 'package:moodiary_diary/src/presentation/search/search_page.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

List<RouteBase> diaryRoutes() => [
  MoodiaryGoRoute(
    path: NewDiaryRoute.path,
    builder: (context, state) {
      final route = NewDiaryRoute.fromState(state);
      return DiaryPage(
        initialType: diaryTypeFromRouteQuery(route.type) ?? .tiptap,
        initialCategoryId: route.categoryId,
        startInEdit: true,
      );
    },
  ),
  MoodiaryGoRoute(
    path: DiaryRoute.path,
    builder: (context, state) {
      final route = DiaryRoute.fromState(state);
      return DiaryPage(
        diaryId: route.diaryId,
        initialType: diaryTypeFromRouteQuery(route.type) ?? .tiptap,
        startInEdit: route.edit,
      );
    },
  ),
  MoodiaryGoRoute(
    path: DiarySearchRoute.path,
    builder: (_, _) => const DiarySearchPage(),
  ),
  MoodiaryGoRoute(
    path: RecycleRoute.path,
    builder: (_, _) => const RecyclePage(),
  ),
  MoodiaryGoRoute(
    path: CategoryManagerRoute.path,
    builder: (_, _) => const CategoryManagerPage(),
  ),
  MoodiaryGoRoute(path: MapRoute.path, builder: (_, _) => const MapPage()),
  MoodiaryGoRoute(
    path: DiaryManagerRoute.path,
    builder: (_, _) => const DiaryManagerPage(),
  ),
  MoodiaryGoRoute(
    path: DiaryGraphRoute.path,
    builder: (_, state) {
      final id = DiaryGraphRoute.fromState(state).diaryId;
      return id == null || id.isEmpty
          ? const DiaryGraphPage()
          : DiaryEgoGraphPage(centerId: id);
    },
  ),
];
