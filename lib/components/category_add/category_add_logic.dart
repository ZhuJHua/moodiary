import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/pages/edit/edit_logic.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';

import '../../utils/data/isar.dart';
import '../../utils/notice_util.dart';
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

  @override
  void onClose() {
    super.onClose();
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
