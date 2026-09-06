import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

Future<void> openNewDiaryEditor(
  BuildContext context,
  DiaryType type, {
  String? categoryId,
}) {
  return NewDiaryRoute(
    type: type.routeQuery,
    categoryId: categoryId,
  ).push(context);
}
