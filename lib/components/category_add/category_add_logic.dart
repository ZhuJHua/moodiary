import 'package:flutter/material.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/pages/edit/edit_logic.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/presentation/isar.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:refreshed/refreshed.dart';

import 'category_add_state.dart';

class CategoryAddLogic extends GetxController {
  final CategoryAddState state = CategoryAddState();
  late final EditLogic editLogic = Bind.find<EditLogic>();
  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onReady() {
    getCategory();
    super.onReady();
  }

  void getCategory() {
    state.categoryList.value = IsarUtil.getAllCategory();
  }

  Future<void> addCategory({required String text}) async {
    if (text.isNotEmpty) {
      var res = await IsarUtil.insertACategory(Category()..categoryName = text);
      if (res == false) {
        NoticeUtil.showToast('已经存在同名分类，已自动重命名');
      }
      getCategory();
      await diaryLogic.updateCategory();
    }
  }

  void selectCategory(int index, BuildContext context) {
    Navigator.pop(context);
    editLogic.selectCategory(state.categoryList.value[index].id);
    editLogic.update(['CategoryName']);
  }

  void cancelCategory(BuildContext context) {
    Navigator.pop(context);
    editLogic.selectCategory(null);
    editLogic.update(['CategoryName']);
  }
}
