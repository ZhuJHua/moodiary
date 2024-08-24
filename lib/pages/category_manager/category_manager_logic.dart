import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/utils/utils.dart';

import 'category_manager_state.dart';

class CategoryManagerLogic extends GetxController {
  final CategoryManagerState state = CategoryManagerState();

  late TextEditingController textEditingController = TextEditingController();

  @override
  void onInit() {
    // TODO: implement onInit
    getCategory();
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    textEditingController.dispose();
    super.onClose();
  }

  Future<void> getCategory() async {
    state.categoryList.value = Utils().isarUtil.getAllCategory();
  }

  Future<void> addCategory() async {
    if (textEditingController.text.isNotEmpty) {
      if (await Utils().isarUtil.insertACategory(Category()..categoryName = textEditingController.text)) {
        Get.backLegacy();
        await getCategory();
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
    }
  }

  Future<void> deleteCategory(String id) async {
    if (await Utils().isarUtil.deleteACategory(id)) {
      Utils().noticeUtil.showToast('删除成功');
      await getCategory();
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
