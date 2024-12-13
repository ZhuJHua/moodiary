import 'package:get/get.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';

import '../../utils/data/isar.dart';
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
    state.isFetching = true;
    update(['PlaceHolder']);
    state.diaryList = await IsarUtil.getDiaryByCategory(state.categoryId, 0, state.initLen);
    state.isFetching = false;
    update(['PlaceHolder']);
    update(['TabView']);
  }

  Future<void> updateDiary() async {
    state.diaryList = await IsarUtil.getDiaryByCategory(state.categoryId, 0, state.initLen);
    update(['PlaceHolder']);
    update(['TabView']);
  }

  Future<void> paginationDiary() async {
    state.diaryList += await IsarUtil.getDiaryByCategory(state.categoryId, state.diaryList.length, state.pageLen);
    update(['TabView']);
  }

  Future<void> getDiaryByDay(DateTime dateTime) async {}
}
