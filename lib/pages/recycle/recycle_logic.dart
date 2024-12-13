import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';

import '../../utils/data/isar.dart';
import '../../utils/file_util.dart';
import '../../utils/notice_util.dart';
import '../../utils/webdav_util.dart';
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
    state.diaryList = await IsarUtil.getRecycleBinDiaries();
    update();
  }

  //长按卡片删除
  Future<void> deleteDiary(index) async {
    //删除日记
    if (await IsarUtil.deleteADiary(state.diaryList[index].isarId)) {
      for (var name in state.diaryList[index].imageName) {
        FileUtil.deleteFile(FileUtil.getRealPath('image', name));
      }
      for (var name in state.diaryList[index].audioName) {
        FileUtil.deleteFile(FileUtil.getRealPath('audio', name));
      }
      for (var name in state.diaryList[index].videoName) {
        FileUtil.deleteFile(FileUtil.getRealPath('video', name));
        // 删除缩略图
        FileUtil.deleteFile(FileUtil.getRealPath('thumbnail', name));
      }
      NoticeUtil.showToast('删除成功');
      await WebDavUtil().deleteSingleDiary(state.diaryList[index]);
      //重新获取
      getDiaryList();
    }
  }

  //重新显示
  Future<void> showDiary(Diary diary) async {
    //将show置为true
    final newDiary = diary.clone()..show = true;
    //写入数据库
    await IsarUtil.updateADiary(oldDiary: diary, newDiary: newDiary);
    //重新获取
    getDiaryList();
    update();
    await diaryLogic.updateDiary(diary.categoryId);
    NoticeUtil.showToast('已恢复');
  }
}
