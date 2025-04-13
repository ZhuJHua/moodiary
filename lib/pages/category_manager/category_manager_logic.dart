import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'category_manager_state.dart';

class CategoryManagerLogic extends GetxController {
  final CategoryManagerState state = CategoryManagerState();

  late DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onReady() async {
    await getCategory();
    super.onReady();
  }

  Future<void> getCategory() async {
    state.isFetching.value = true;
    state.categoryList.value = await IsarUtil.getAllCategoryAsync();
    state.isFetching.value = false;
  }

  Future<void> addCategory({required String text}) async {
    if (text.isNotEmpty) {
      if (await IsarUtil.insertACategory(Category()..categoryName = text)) {
        await getCategory();
        await diaryLogic.updateCategory();
      } else {
        await getCategory();
        await diaryLogic.updateCategory();
        toast.info(message: '分类已存在，已自动添加后缀');
      }
    } else {
      toast.info(message: '分类名称不能为空');
    }
  }

  Future<void> editCategory(String categoryId, {required String text}) async {
    if (text.isNotEmpty) {
      await IsarUtil.updateACategory(
        Category()
          ..id = categoryId
          ..categoryName = text,
      );
      await getCategory();
      await diaryLogic.updateCategory();
    } else {
      toast.info(message: '分类名称不能为空');
    }
  }

  Future<void> deleteCategory(String id) async {
    if (await IsarUtil.deleteACategory(id)) {
      toast.success(message: '删除成功');
      await getCategory();
      await diaryLogic.updateCategory();
    } else {
      toast.error(message: '删除失败，当前分类下还有日记');
    }
  }
}
