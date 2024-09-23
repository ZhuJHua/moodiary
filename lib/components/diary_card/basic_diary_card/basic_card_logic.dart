import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:mood_diary/pages/home/calendar/calendar_logic.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

mixin BasicCardLogic {
  Future<void> toDiary(Diary diary) async {
    await HapticFeedback.mediumImpact();
    var res = await Get.toNamed(AppRoutes.diaryPage, arguments: diary);
    var oldCategoryId = diary.categoryId;
    if (res == 'delete') {
      //如果分类为空，删除主页即可，如果分类不为空，双删除
      if (diary.categoryId != null) {
        Bind.find<DiaryTabViewLogic>(tag: diary.categoryId).state.diaryList.removeWhere((e) => e.id == diary.id);
      }
      Bind.find<DiaryTabViewLogic>(tag: 'default').state.diaryList.removeWhere((e) => e.id == diary.id);
    } else {
      //重新获取日记
      var newDiary = await Utils().isarUtil.getDiaryByID(diary.id);
      if (newDiary != null) {
        var newCategoryId = newDiary.categoryId;
        //如果没修改
        if (diary == newDiary) {
          return;
        }
        //如果修改了但是没有修改分类，就替换掉原来的
        if (oldCategoryId == newCategoryId) {
          await Bind.find<DiaryLogic>().updateDiary(oldCategoryId);
        } else {
          //如果修改了分类
          //再去新的分类
          await Bind.find<DiaryLogic>().updateDiary(newCategoryId);
          //先改旧分类
          await Bind.find<DiaryLogic>().updateDiary(oldCategoryId, jump: false);
        }
      }
    }
  }

  Future<void> toDiaryInCalendar(Diary diary) async {
    await HapticFeedback.mediumImpact();
    var res = await Get.toNamed(AppRoutes.diaryPage, arguments: diary);
    if (res == 'delete') {
      Bind.find<CalendarLogic>().state.diaryList.removeWhere((e) => e.id == diary.id);
    } else {
      await Bind.find<CalendarLogic>().getDiary();
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
