import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/channel.dart';
import 'package:uuid/uuid.dart';

import '../../utils/data/pref.dart';

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
      await setUuid();
      //await SupabaseUtil().initSupabase();
      //await Utils().updateUtil.initShiply();
    }
    Get.offAllNamed(AppRoutes.homePage);
  }

  Future<void> setUuid() async {
    var oaid = await OAIDChannel.getOAID();
    if (oaid != null) {
      await PrefUtil.setValue<String>(
          'uuid', md5.convert(utf8.encode(oaid)).toString());
    } else {
      await PrefUtil.setValue<String>(
          'uuid', md5.convert(utf8.encode(const Uuid().v7())).toString());
    }
  }
}
