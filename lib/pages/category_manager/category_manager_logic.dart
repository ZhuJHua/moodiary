import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'category_manager_state.dart';

class CategoryManagerLogic extends GetxController {
  final CategoryManagerState state = CategoryManagerState();

  late TextEditingController textEditingController = TextEditingController();

  late DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onReady() async {
    await getCategory();
    super.onReady();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }

  Future<void> getCategory() async {
    state.categoryList.value = await Utils().isarUtil.getAllCategoryAsync();
  }

  Future<void> addCategory() async {
    if (textEditingController.text.isNotEmpty) {
      if (await Utils().isarUtil.insertACategory(Category()..categoryName = textEditingController.text)) {
        Get.backLegacy();
        await getCategory();
        await diaryLogic.updateCategory();
      } else {
        textEditingController.clear();
        Utils().noticeUtil.showToast('分类已存在');
      }
    }
  }

  Future<void> editCategory(String categoryId) async {
    if (textEditingController.text.isNotEmpty) {
      await Utils().isarUtil.updateACategory(Category()
        ..id = categoryId
        ..categoryName = textEditingController.text);
      Get.backLegacy();
      await getCategory();
      await diaryLogic.updateCategory();
    }
  }

  Future<void> deleteCategory(String id) async {
    if (await Utils().isarUtil.deleteACategory(id)) {
      Utils().noticeUtil.showToast('删除成功');
      await getCategory();
      await diaryLogic.updateCategory();
    } else {
      Utils().noticeUtil.showToast('删除失败，当前分类下还有日记');
    }
  }

  void clearInput() {
    textEditingController.clear();
  }

  void editInput(String value) {
    textEditingController.text = value;
  }
}
