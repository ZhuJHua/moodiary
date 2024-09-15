import 'package:get/get.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_tab_view_state.dart';

class DiaryTabViewLogic extends GetxController {
  final DiaryTabViewState state = DiaryTabViewState();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onInit() {
    // TODO: implement onInit

    super.onInit();
  }

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

  Future<void> initDiary(String? categoryId) async {
    state.categoryId = categoryId;
    await getDiary();
  }

  Future<void> getDiary() async {
    state.isFetching.value = true;
    state.diaryList.value = await Utils().isarUtil.getDiaryByCategory(state.categoryId, 0, state.initLen);
    state.isFetching.value = false;
  }

  Future<void> paginationDiary(int offset) async {
    state.diaryList.value += await Utils().isarUtil.getDiaryByCategory(state.categoryId, offset, state.pageLen);
  }

  Future<void> getDiaryByDay(DateTime dateTime) async {}
}
