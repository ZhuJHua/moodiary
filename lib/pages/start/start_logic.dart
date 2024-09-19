import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/channel.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'start_state.dart';

class StartLogic extends GetxController {
  final StartState state = StartState();

  @override
  void onInit() {
    // TODO: implement onInit
    //如果不是首次启动，直接进入
    super.onInit();
  }

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

  void toPrivacy() {
    Get.toNamed(AppRoutes.privacyPage);
  }

  void toAgreement() {
    Get.toNamed(AppRoutes.agreementPage);
  }

  Future<void> toHome() async {
    await Utils().prefUtil.setValue<bool>('firstStart', false);
    if (Platform.isAndroid) {
      await setUuid();
      //await Utils().supabaseUtil.initSupabase();
      //await Utils().updateUtil.initShiply();
    }
    Get.offAllNamed(AppRoutes.homePage);
  }

  Future<void> setUuid() async {
    var oaid = await OAIDChannel.getOAID();
    if (oaid != null) {
      await Utils().prefUtil.setValue<String>('uuid', md5.convert(utf8.encode(oaid)).toString());
    } else {
      await Utils().prefUtil.setValue<String>('uuid', md5.convert(utf8.encode(const Uuid().v7())).toString());
    }
  }
}
