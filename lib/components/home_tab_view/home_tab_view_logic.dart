import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'home_tab_view_state.dart';

class HomeTabViewLogic extends GetxController {
  final HomeTabViewState state = HomeTabViewState();

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
    //如果分类不为空说明是按照分类查询，否则查询全部
    if (state.categoryId != null) {
      state.diaryList.value = await Utils().isarUtil.getDiaryByCategory(state.categoryId!, 0, 10);
    } else {
      //默认分页10篇
      state.diaryList.value = await Utils().isarUtil.getAllDiary(0, 10);
    }
    state.isFetching.value = false;
  }

  Future<void> paginationDiary(int offset, int limit) async {
    if (state.categoryId != null) {
      state.diaryList.value = await Utils().isarUtil.getDiaryByCategory(state.categoryId!, offset, limit);
    } else {
      state.diaryList.value += await Utils().isarUtil.getAllDiary(offset, limit);
    }
  }
}
