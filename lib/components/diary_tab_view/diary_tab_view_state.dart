import 'package:moodiary/common/models/isar/diary.dart';
import 'package:refreshed/refreshed.dart';

class DiaryTabViewState {
  RxList<Diary> diaryList = <Diary>[].obs;

  RxBool isFetching = true.obs;

  //首次加载的个数
  int initLen = 30;

  //分页的个数
  int pageLen = 20;

  late String? categoryId;

  DiaryTabViewState();
}
