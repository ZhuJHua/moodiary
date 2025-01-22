import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/presentation/isar.dart';
import 'package:refreshed/refreshed.dart';

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
    state.diaryList =
        await IsarUtil.getDiaryByCategory(state.categoryId, 0, state.initLen);
    state.isFetching = false;
    update();
  }

  Future<void> updateDiary() async {
    state.isFetching = true;
    state.diaryList =
        await IsarUtil.getDiaryByCategory(state.categoryId, 0, state.initLen);
    state.isFetching = false;
    update();
  }

  Future<void> paginationDiary() async {
    state.diaryList += await IsarUtil.getDiaryByCategory(
        state.categoryId, state.diaryList.length, state.pageLen);
    update(['view']);
  }
}
