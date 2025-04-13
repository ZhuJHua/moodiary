import 'package:get/get.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';

import 'diary_tab_view_state.dart';

class DiaryTabViewLogic extends GetxController {
  final DiaryTabViewState state = DiaryTabViewState();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  DiaryTabViewLogic({required String? categoryId}) {
    state.categoryId = categoryId;
  }

  @override
  void onReady() async {
    await _getDiary();
    super.onReady();
  }

  Future<void> _getDiary() async {
    state.isFetching.value = true;
    state.diaryList.value = await IsarUtil.getDiaryByCategory(
      state.categoryId,
      0,
      state.initLen,
    );
    state.isFetching.value = false;
  }

  Future<void> updateDiary() async {
    state.isFetching.value = true;
    state.diaryList.value = await IsarUtil.getDiaryByCategory(
      state.categoryId,
      0,
      state.initLen,
    );
    state.isFetching.value = false;
  }

  Future<void> paginationDiary() async {
    state.diaryList.value += await IsarUtil.getDiaryByCategory(
      state.categoryId,
      state.diaryList.length,
      state.pageLen,
    );
  }
}
