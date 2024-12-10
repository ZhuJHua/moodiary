import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/utils.dart';
import 'backup_sync_state.dart';

class BackupSyncLogic extends GetxController {
  final BackupSyncState state = BackupSyncState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<void> exportFile() async {
    Get.backLegacy();
    Utils().noticeUtil.showToast('正在处理中');
    final dataPath = Utils().fileUtil.getRealPath('', '');
    final zipPath = Utils().fileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    var path = await compute(Utils().fileUtil.zipFile, isolateParams);
    Utils().logUtil.printInfo(path);
    await Share.shareXFiles([XFile(path)]);
  }

  //导入
  Future<void> import() async {
    Get.backLegacy();
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowedExtensions: ['zip'], type: FileType.custom);
    if (result != null) {
      Utils().noticeUtil.showToast('数据导入中，请不要离开页面');
      await Utils().fileUtil.extractFile(result.files.single.path!);
      Utils().noticeUtil.showToast('导入成功，请重启应用');
    } else {
      Utils().noticeUtil.showToast('取消文件选择');
    }
  }
}
