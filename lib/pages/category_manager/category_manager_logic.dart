import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/isar.dart';
import '../../utils/notice_util.dart';
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
        NoticeUtil.showToast('分类已存在，已自动添加后缀');
      }
    } else {
      NoticeUtil.showToast('分类名称不能为空');
    }
  }

  Future<void> editCategory(String categoryId, {required String text}) async {
    if (text.isNotEmpty) {
      await IsarUtil.updateACategory(Category()
        ..id = categoryId
        ..categoryName = text);
      await getCategory();
      await diaryLogic.updateCategory();
    } else {
      NoticeUtil.showToast('分类名称不能为空');
    }
  }

  Future<void> deleteCategory(String id) async {
    if (await IsarUtil.deleteACategory(id)) {
      NoticeUtil.showToast('删除成功');
      await getCategory();
      await diaryLogic.updateCategory();
    } else {
      NoticeUtil.showToast('删除失败，当前分类下还有日记');
    }
  }
}
