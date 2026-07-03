import 'package:flutter/widgets.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

/// 打开日记详情 —— 列表 / 网格 / 日历卡片共用的导航入口。卡片本身只收 `onTap`，
/// 路由逻辑集中于此，卡片保持展示纯净、可复用。
void openDiaryDetail(BuildContext context, Diary diary) {
  DiaryRoute(
    type: DiaryType.fromValue(diary.type).routeQuery,
    diaryId: diary.id,
  ).push(context);
}
