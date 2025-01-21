import 'package:flutter/cupertino.dart';
import 'package:moodiary/common/models/isar/diary.dart';

class ShareState {
  late GlobalKey key;

  late Diary diary;

  ShareState() {
    key = GlobalKey();

    ///Initialize variables
  }
}
