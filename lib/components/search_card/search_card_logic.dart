import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/pages/diary_details/diary_details_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

import 'search_card_state.dart';

class SearchCardLogic extends GetxController {
  final SearchCardState state = SearchCardState();

  //选中卡片后跳转到详情页，直接携带Diary作为参数
  Future<void> toDiaryPage(Diary diary) async {
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
    await Get.toNamed(AppRoutes.diaryPage, arguments: [diary.clone(), false]);
  }
}
