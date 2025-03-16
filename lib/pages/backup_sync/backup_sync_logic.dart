import 'package:file_picker/file_picker.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:share_plus/share_plus.dart';

class BackupSyncLogic extends GetxController {
  Future<void> exportFile() async {
    NoticeUtil.showToast('正在处理中');
    final dataPath = FileUtil.getRealPath('', '');
    final zipPath = FileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    final path = await FileUtil.zipFileUseRust(isolateParams);
    LogUtil.printInfo(path);
    await Share.shareXFiles([XFile(path)]);
  }

  //导入
  Future<void> import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result != null) {
      NoticeUtil.showToast('数据导入中，请不要离开页面');
      await FileUtil.extractFile(result.files.single.path!);
      NoticeUtil.showToast('导入成功，请重启应用');
    } else {
      NoticeUtil.showToast('取消文件选择');
    }
  }
}
