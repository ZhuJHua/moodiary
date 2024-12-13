import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/pages/edit/edit_logic.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';

import '../../utils/data/isar.dart';
import '../../utils/notice_util.dart';
import 'category_add_state.dart';

class CategoryAddLogic extends GetxController {
  final CategoryAddState state = CategoryAddState();
  late TextEditingController textEditingController = TextEditingController();
  late final EditLogic editLogic = Bind.find<EditLogic>();
  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onReady() {
    getCategory();
    super.onReady();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }

  void getCategory() {
    state.categoryList.value = IsarUtil.getAllCategory();
  }

  Future<void> addCategory() async {
    if (textEditingController.text.isNotEmpty) {
      if (await IsarUtil.insertACategory(Category()..categoryName = textEditingController.text)) {
        Get.backLegacy();
        textEditingController.clear();
        getCategory();
        await diaryLogic.updateCategory();
      } else {
        textEditingController.clear();
        NoticeUtil.showToast('分类已存在');
      }
    }
  }

  void cancelAdd() {
    textEditingController.clear();
    Get.backLegacy();
  }

  void selectCategory(int index) {
    Get.backLegacy();
    editLogic.selectCategory(state.categoryList.value[index].id);
    editLogic.update(['CategoryName']);
  }

  void cancelCategory() {
    Get.backLegacy();
    editLogic.selectCategory(null);
    editLogic.update(['CategoryName']);
  }
}
