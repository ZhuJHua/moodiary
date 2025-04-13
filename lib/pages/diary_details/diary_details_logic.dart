import 'dart:async';

import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

import 'diary_details_state.dart';

class DiaryDetailsLogic extends GetxController {
  final DiaryDetailsState state = DiaryDetailsState();

  //点击分享跳转到分享页面
  Future<void> toSharePage() async {
    Get.toNamed(AppRoutes.sharePage, arguments: state.diary);
  }

  //编辑日记
  Future<void> toEditPage(Diary diary) async {
    //这里参数为diary，表示编辑日记，等待跳转结果为changed，重新获取日记
    if ((await Get.toNamed(AppRoutes.editPage, arguments: diary.clone())) ==
        'changed') {
      //重新获取日记
      state.diary = (await IsarUtil.getDiaryByID(state.diary.isarId))!;
      // if (state.diary.type != DiaryType.markdown.value) {
      //   quillController = QuillController(
      //     document: Document.fromJson(jsonDecode(state.diary.content)),
      //     readOnly: true,
      //     selection: const TextSelection.collapsed(offset: 0),
      //   );
      // }
      update();
    }
  }

  //放入回收站
  Future<void> delete(Diary diary) async {
    final newDiary = diary.clone()..show = false;
    await IsarUtil.updateADiary(oldDiary: diary, newDiary: newDiary);
    Get.back(result: 'delete');
  }
}
