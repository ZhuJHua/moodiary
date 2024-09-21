import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'calendar_state.dart';

class CalendarLogic extends GetxController {
  final CalendarState state = CalendarState();

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
    state.diaryList.value = await Utils().isarUtil.getDiaryByDay(state.selectedDate.first);
    state.isFetching.value = false;
  }

  // 选中日期后重新获取日记
  Future<void> updateDate(value) async {
    state.selectedDate = value;
    await getDiary();
  }
}
