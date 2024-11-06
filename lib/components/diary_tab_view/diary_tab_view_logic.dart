import 'package:get/get.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_tab_view_state.dart';

class DiaryTabViewLogic extends GetxController {
  final DiaryTabViewState state = DiaryTabViewState();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  DiaryTabViewLogic({required String? categoryId}) {
    state.categoryId = categoryId;
  }

  @override
  void onReady() async {
    await getDiary();
    super.onReady();
  }

  Future<void> getDiary() async {
    state.isFetching = true;
    update(['PlaceHolder']);
    state.diaryList = await Utils()
        .isarUtil
        .getDiaryByCategory(state.categoryId, 0, state.initLen);
    state.isFetching = false;
    update(['PlaceHolder']);
    update(['TabView']);
  }

  Future<void> paginationDiary() async {
    state.diaryList += await Utils().isarUtil.getDiaryByCategory(
        state.categoryId, state.diaryList.length, state.pageLen);
  }

  Future<void> getDiaryByDay(DateTime dateTime) async {}
}
