import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/router/app_routes.dart';

import 'large_diary_card_state.dart';

class LargeDiaryCardLogic extends GetxController {
  final LargeDiaryCardState state = LargeDiaryCardState();
  late HomeLogic homeLogic = Bind.find<HomeLogic>();

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

  Future<void> toDiary(Diary diary) async {
    var res = await Get.toNamed(AppRoutes.diaryPage, arguments: diary);
    //返回后切换回app主题
    if (res == 'delete') {
      await homeLogic.updateDiary();
    }
  }
}
