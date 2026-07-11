import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:share_plus/share_plus.dart';

class BackupSyncLogic extends GetxController {
  Future<void> exportFile() async {
    // 用持续显示的 loading（而非几秒后自动消失的 toast），打包完成或失败前不会消失
    unawaited(toast.loading(message: '正在打包数据，请稍候…'));
    try {
      final dataPath = FileUtil.getRealPath('', '');
      final zipPath = FileUtil.getCachePath('');
      final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
      final path = await FileUtil.zipFileUseRust(isolateParams);
      await toast.dismiss();
      final res = await SharePlus.instance.share(
        ShareParams(files: [XFile(path)]),
      );
      if (res.status == ShareResultStatus.success) {
        await File(path).delete();
      }
    } catch (e, s) {
      logger.e('导出备份失败', error: e, stackTrace: s);
      await toast.dismiss();
      unawaited(toast.error(message: '导出失败：$e'));
    }
  }

  //导入
  Future<void> import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result != null) {
      unawaited(toast.loading(message: '数据导入中，请不要离开页面'));
      try {
        await FileUtil.extractFile(result.files.single.path!);
        await toast.dismiss();
        unawaited(toast.success(message: '导入成功，请重启应用'));
      } catch (e, s) {
        logger.e('导入备份失败', error: e, stackTrace: s);
        await toast.dismiss();
        unawaited(toast.error(message: '导入失败：$e'));
      }
    } else {
      unawaited(toast.info(message: '取消文件选择'));
    }
  }
}
