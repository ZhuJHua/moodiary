import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:share_plus/share_plus.dart';

class BackupSyncLogic extends GetxController {
  Future<void> exportFile() async {
    toast.info(message: '正在处理中');
    final dataPath = FileUtil.getRealPath('', '');
    final zipPath = FileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    final path = await FileUtil.zipFileUseRust(isolateParams);
    final res = await Share.shareXFiles([XFile(path)]);
    if (res.status == ShareResultStatus.success) {
      await File(path).delete();
    }
  }

  //导入
  Future<void> import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result != null) {
      toast.info(message: '数据导入中，请不要离开页面');
      await FileUtil.extractFile(result.files.single.path!);
      toast.success(message: '导入成功，请重启应用');
    } else {
      toast.info(message: '取消文件选择');
    }
  }
}
