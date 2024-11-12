import 'package:mood_diary/common/models/isar/diary.dart';

class DiaryTabViewState {
  late List<Diary> diaryList = <Diary>[];

  late bool isFetching = false;

  //首次加载的个数
  late int initLen;

  //分页的个数
  late int pageLen;

  late String? categoryId;

  DiaryTabViewState() {
    initLen = 30;
    pageLen = 20;

    ///Initialize variables
  }
}
