import 'package:flutter/widgets.dart';
import 'package:moodiary_router/moodiary_router.dart';

void openDiaryDetail(BuildContext context, String diaryId) {
  DiaryRoute(diaryId: diaryId).push(context);
}
