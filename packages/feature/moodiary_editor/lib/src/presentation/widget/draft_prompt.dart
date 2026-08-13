import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

/// 连点 FAB 会压入两个无 id 的 `/diary-new`，它们归一到同一个 EditController、串写同一条
/// 草稿而错乱；用此闸门保证同一时刻只有一个新建页在途。
bool _openingNewDiary = false;

/// FAB「新建日记」入口。延迟落库：不预先插入空日记，有内容才由 [EditController] 落库。
Future<void> openNewDiaryEditor(
  BuildContext context,
  DiaryType type, {
  String? categoryId,
}) async {
  if (_openingNewDiary) return;
  _openingNewDiary = true;
  try {
    await NewDiaryRoute(
      type: type.routeQuery,
      categoryId: categoryId,
    ).push(context);
  } finally {
    _openingNewDiary = false;
  }
}
