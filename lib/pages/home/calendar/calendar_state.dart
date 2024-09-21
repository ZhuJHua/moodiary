import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class CalendarState {
  //选中的时间，他必须是一个List，非常弱智
  late List<DateTime> selectedDate;

  //包含日记的日期
  late List<DateTime> dateHasDiary;
  //当前选中日期内的日记列表
  late RxList<Diary> diaryList;

  late RxBool isFetching;

  CalendarState() {
    //默认是今天
    selectedDate = [DateTime.now()];
    dateHasDiary=[];
    diaryList = <Diary>[].obs;
    isFetching=false.obs;

    ///Initialize variables
  }
}
