import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'recycle_state.dart';

class RecycleLogic extends GetxController {
  final RecycleState state = RecycleState();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onReady() {
    getDiaryList();
    super.onReady();
  }

  Future<void> getDiaryList() async {
    state.diaryList = await Utils().isarUtil.getRecycleBinDiaries();
    update();
  }

  //长按卡片删除
  Future<void> deleteDiary(index) async {
    //删除日记
    if (await Utils().isarUtil.deleteADiary(state.diaryList[index].isarId)) {
      for (var name in state.diaryList[index].imageName) {
        Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath('image', name));
      }
      for (var name in state.diaryList[index].audioName) {
        Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath('audio', name));
      }
      for (var name in state.diaryList[index].videoName) {
        Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath('video', name));
      }
      Utils().noticeUtil.showToast('删除成功');
      //重新获取
      getDiaryList();
    }
  }

  //重新显示
  Future<void> showDiary(Diary diary) async {
    //将show置为true
    diary.show = true;
    //写入数据库
    await Utils().isarUtil.updateADiary(diary);
    //重新获取
    getDiaryList();
    update();
    await diaryLogic.updateDiary(diary.categoryId);
    Utils().noticeUtil.showToast('已恢复');
  }
}
