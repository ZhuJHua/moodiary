import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';

class HomeTabViewState {
  late RxList<Diary> diaryList;

  late RxBool isFetching;

  late String? categoryId;

  HomeTabViewState() {
    diaryList = <Diary>[].obs;
    isFetching = false.obs;

    ///Initialize variables
  }
}
