import 'package:moodiary/common/models/isar/diary.dart';

class DiaryTabViewState {
  List<Diary> diaryList = <Diary>[];

  bool isFetching = true;

  //首次加载的个数
  int initLen = 30;

  //分页的个数
  int pageLen = 20;

  late String? categoryId;

  DiaryTabViewState();
}
