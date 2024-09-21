import 'package:get/get.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_tab_view_state.dart';

class DiaryTabViewLogic extends GetxController {
  final String? categoryId;
  final DiaryTabViewState state = DiaryTabViewState();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  DiaryTabViewLogic({required this.categoryId});

  @override
  void onInit() {
    // TODO: implement onInit

    super.onInit();
  }

  @override
  void onReady() async {
    await getDiary();
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose

    super.onClose();
  }

  Future<void> getDiary() async {
    state.isFetching.value = true;
    state.diaryList.value = await Utils().isarUtil.getDiaryByCategory(categoryId, 0, state.initLen);
    state.isFetching.value = false;
  }

  Future<void> paginationDiary() async {
    state.diaryList += await Utils().isarUtil.getDiaryByCategory(categoryId, state.diaryList.length, state.pageLen);
  }

  Future<void> getDiaryByDay(DateTime dateTime) async {}
}
