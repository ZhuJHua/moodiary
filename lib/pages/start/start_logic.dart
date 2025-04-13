import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/channel.dart';
import 'package:moodiary/utils/package_util.dart';
import 'package:uuid/uuid.dart';

class StartLogic extends GetxController {
  void toPrivacy() {
    Get.toNamed(AppRoutes.privacyPage);
  }

  void toAgreement() {
    Get.toNamed(AppRoutes.agreementPage);
  }

  Future<void> toHome() async {
    await PrefUtil.setValue<bool>('firstStart', false);
    if (Platform.isAndroid) {
      //await SupabaseUtil().initSupabase();
      //await Utils().updateUtil.initShiply();
    }
    await setUuid();
    Get.offAllNamed(AppRoutes.homePage);
  }

  Future<void> setUuid() async {
    String? oaid;
    switch (Platform.operatingSystem) {
      case 'android':
        oaid = await OAIDChannel.getOAID();
        break;
      case 'ios':
        oaid =
            ((await PackageUtil.getInfo()) as IosDeviceInfo)
                .identifierForVendor;
        break;
      case 'macos':
        oaid = ((await PackageUtil.getInfo()) as MacOsDeviceInfo).systemGUID;
        break;
      case 'windows':
        oaid = ((await PackageUtil.getInfo()) as WindowsDeviceInfo).deviceId;
        break;
    }
    if (oaid != null) {
      await PrefUtil.setValue<String>(
        'uuid',
        md5.convert(utf8.encode(oaid)).toString(),
      );
    } else {
      await PrefUtil.setValue<String>(
        'uuid',
        md5.convert(utf8.encode(const Uuid().v7())).toString(),
      );
    }
  }
}
