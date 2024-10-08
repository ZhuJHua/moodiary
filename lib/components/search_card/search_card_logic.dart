import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/router/app_routes.dart';

import 'search_card_state.dart';

class SearchCardLogic extends GetxController {
  final SearchCardState state = SearchCardState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  //选中卡片后跳转到详情页，直接携带Diary作为参数
  Future<void> toDiaryPage(Diary diary) async {
    await Get.toNamed(AppRoutes.diaryPage, arguments: [diary, false]);
  }
}
