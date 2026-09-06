import 'package:flutter/widgets.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

void openDiaryDetail(BuildContext context, Diary diary) {
  DiaryRoute(
    type: DiaryType.fromValue(diary.type).routeQuery,
    diaryId: diary.id,
  ).push(context);
}
