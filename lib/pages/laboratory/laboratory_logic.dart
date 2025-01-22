import 'dart:async';
import 'dart:io';

import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:share_plus/share_plus.dart';

class LaboratoryLogic extends GetxController {
  Future<void> setTencentID({required String id, required String key}) async {
    await PrefUtil.setValue<String>('tencentId', id);
    await PrefUtil.setValue<String>('tencentKey', key);
    update();
  }

  Future<void> setQweatherKey({required String key}) async {
    await PrefUtil.setValue<String>('qweatherKey', key);
    update();
  }

  Future<void> setTiandituKey({required String key}) async {
    await PrefUtil.setValue<String>('tiandituKey', key);
    update();
  }

  Future<void> exportErrorLog() async {
    // 如果日志内容存在且内容不为空则导出
    if ((await File(FileUtil.getErrorLogPath()).readAsString()).isNotEmpty) {
      var result = await Share.shareXFiles([XFile(FileUtil.getErrorLogPath())]);
      // 如果分享成功则清空本地日志
      if (result.status == ShareResultStatus.success) {
        await File(FileUtil.getErrorLogPath()).writeAsString('');
        NoticeUtil.showToast('日志导出成功，已删除本地日志');
      }
    } else {
      NoticeUtil.showToast('暂无日志');
    }
  }
}
