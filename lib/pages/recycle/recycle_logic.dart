import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/webdav_util.dart';

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

  Future<void> deleteDiary(int index) async {
    final diary = state.diaryList[index];
    try {
      await WebDavUtil().deleteSingleDiary(diary);
    } catch (e) {
      toast.info(message: '当前已断开与WebDAV的连接，无法删除');
      return;
    }
    if (await IsarUtil.deleteADiary(diary.isarId)) {
      final imageDeleteTasks = diary.imageName.map(
        (name) => FileUtil.deleteFile(FileUtil.getRealPath('image', name)),
      );
      final audioDeleteTasks = diary.audioName.map(
        (name) => FileUtil.deleteFile(FileUtil.getRealPath('audio', name)),
      );
      final videoDeleteTasks = diary.videoName.map((name) async {
        // 删除视频文件
        await FileUtil.deleteFile(FileUtil.getRealPath('video', name));
        // 删除视频缩略图
        await FileUtil.deleteFile(FileUtil.getRealPath('thumbnail', name));
      });
      // 合并所有删除任务并发执行
      await Future.wait([
        ...imageDeleteTasks,
        ...audioDeleteTasks,
        ...videoDeleteTasks,
      ]);
      toast.success(message: '删除成功');
      // 重新获取日记列表
      await getDiaryList();
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
    toast.success(message: '已恢复');
  }
}
