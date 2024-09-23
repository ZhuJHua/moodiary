import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'calendar_state.dart';

class CalendarLogic extends GetxController {
  final CalendarState state = CalendarState();

  @override
  void onReady() async {
    await getDateHasDiary(state.currentMonth.value);
    await getDiary();
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<void> getDateHasDiary(DateTime value) async {
    state.currentMonth.value = value;
    state.dateHasDiary.value = await Utils().isarUtil.getDiaryDateByMonth(value.year, value.month);
    update();
  }

  Future<void> getDiary() async {
    state.diaryList.value = await Utils().isarUtil.getDiaryByDay(state.selectedDate.value);
  }

  // 选中日期后重新获取日记
  Future<void> updateDate(DateTime value) async {
    state.selectedDate.value = value;
    await getDiary();
  }

  //回到今天
  Future<void> backToToday() async {
    var now = DateTime.now();
    await updateDate(now);
    await getDateHasDiary(now);
  }

  void open(value) {
    state.isExpanded.value = value;
  }
}
