import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

mixin BasicCardLogic {
  Future<void> toDiary(Diary diary, String tabViewTag) async {
    await HapticFeedback.mediumImpact();
    var res = await Get.toNamed(AppRoutes.diaryPage, arguments: diary);
    var oldCategoryId = diary.categoryId;
    if (res == 'delete') {
      Bind.find<DiaryTabViewLogic>(tag: tabViewTag).state.diaryList.removeWhere((e) => e.id == diary.id);
      // 不知道有没有修改，就当修改了吧
    } else {
      //重新获取日记
      var newDiary = (await Utils().isarUtil.getDiaryByID(diary.id));
      if (newDiary != null) {
        var newCategoryId = newDiary.categoryId;

        //如果没有修改分类，就替换掉原来的
        if (oldCategoryId == newCategoryId) {
          var oldIndex =
              Bind.find<DiaryTabViewLogic>(tag: tabViewTag).state.diaryList.indexWhere((e) => e.id == diary.id);
          Bind.find<DiaryTabViewLogic>(tag: tabViewTag)
              .state
              .diaryList
              .replaceRange(oldIndex, oldIndex + 1, [newDiary]);
        } else {
          //如果修改了分类
          //先去新的分类
          await Bind.find<DiaryLogic>().updateDiary(newCategoryId);
          //在改旧分类
          await Bind.find<DiaryLogic>().updateDiary(oldCategoryId);
        }
      }
    }
  }

  int getMaxLines(String context) {
    return switch (context.length) {
      >= 20 && < 30 => 2,
      >= 30 && < 40 => 3,
      >= 40 => 4,
      _ => 1,
    };
  }
}
