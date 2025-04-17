import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/aes_util.dart';
import 'package:moodiary/utils/cache_util.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:share_plus/share_plus.dart';

class LaboratoryLogic extends GetxController {
  Future<bool> setTencentID({required String id}) async {
    try {
      await PrefUtil.setValue<String>('tencentId', id);
      return true;
    } catch (e) {
      return false;
    } finally {
      update();
    }
  }

  Future<bool> setTencentKey({required String key}) async {
    try {
      await PrefUtil.setValue<String>('tencentKey', key);
      return true;
    } catch (e) {
      return false;
    } finally {
      update();
    }
  }

  Future<bool> setQweatherKey({required String key}) async {
    try {
      await PrefUtil.setValue<String>('qweatherKey', key);
      return true;
    } catch (e) {
      return false;
    } finally {
      update();
    }
  }

  Future<bool> setTiandituKey({required String key}) async {
    try {
      await PrefUtil.setValue<String>('tiandituKey', key);
      return true;
    } catch (e) {
      return false;
    } finally {
      update();
    }
  }

  Future<void> exportErrorLog() async {
    // 如果日志内容存在且内容不为空则导出
    if ((await File(FileUtil.getErrorLogPath()).readAsString()).isNotEmpty) {
      final result = await Share.shareXFiles([
        XFile(FileUtil.getErrorLogPath()),
      ]);
      // 如果分享成功则清空本地日志
      if (result.status == ShareResultStatus.success) {
        await File(FileUtil.getErrorLogPath()).writeAsString('');
        toast.success(message: '日志导出成功，已删除本地日志');
      }
    } else {
      toast.info(message: '暂无日志');
    }
  }

  Future<bool> aesTest() async {
    final key = await AesUtil.deriveKey(salt: 'salt', userKey: 'password');
    final encrypted = await AesUtil.encrypt(key: key, data: 'Hello World');
    final decrypted = await AesUtil.decrypt(key: key, encryptedData: encrypted);
    return decrypted == 'Hello World';
  }

  Future<bool> clearImageThumbnail() async {
    try {
      await ImageCacheUtil().clearImageCache();
      return true;
    } catch (e) {
      return false;
    }
  }
}
