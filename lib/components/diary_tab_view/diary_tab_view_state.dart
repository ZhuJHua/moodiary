import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryTabViewState {
  late RxList<Diary> diaryList;

  late RxBool isFetching;


  //首次加载的个数
  late int initLen;

  //分页的个数
  late int pageLen;



  DiaryTabViewState() {
    diaryList = <Diary>[].obs;
    isFetching = false.obs;
    initLen = 30;
    pageLen = 20;

    ///Initialize variables
  }
}
