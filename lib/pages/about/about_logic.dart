import 'package:confetti/confetti.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/package_util.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_state.dart';

class AboutLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final AboutState state = AboutState();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);
  late final animation = Tween<double>(begin: -0.06, end: 0.06).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
  );

  late final ConfettiController confettiController = ConfettiController(
    duration: const Duration(seconds: 4),
  );

  @override
  void onReady() async {
    await getInfo();
    super.onReady();
  }

  @override
  void onClose() {
    _animationController.dispose();
    confettiController.dispose();
    super.onClose();
  }

  Future<void> getInfo() async {
    final packageInfo = await PackageUtil.getPackageInfo();
    final deviceInfo = await PackageUtil.getInfo();
    if (deviceInfo is AndroidDeviceInfo) {
      state.systemVersion = 'Android ${deviceInfo.version.release}';
    } else if (deviceInfo is IosDeviceInfo) {
      state.systemVersion =
          '${deviceInfo.systemName} ${deviceInfo.systemVersion}';
    } else if (deviceInfo is WindowsDeviceInfo) {
      state.systemVersion = 'Windows ${deviceInfo.majorVersion}';
    } else if (deviceInfo is MacOsDeviceInfo) {
      state.systemVersion = 'MacOS ${deviceInfo.majorVersion} ';
    }
    state.appName = packageInfo.appName;
    state.appVersion = '${packageInfo.version}(${packageInfo.buildNumber})';
    state.isFetching.value = false;
  }

  //跳转到反馈页
  Future<void> toReportPage() async {
    await Get.toNamed(
      AppRoutes.webViewPage,
      arguments: ['https://answer.moodiary.net', ''],
    );
    //await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  //跳转至源代码
  Future<void> toSource() async {
    final uri = Uri(
      scheme: 'https',
      host: 'github.com',
      path: 'ZhuJHua/moodiary',
    );
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  void playConfetti() {
    HapticFeedback.selectionClick();
    confettiController.play();
  }

  void toPrivacy() {
    Get.toNamed(AppRoutes.privacyPage);
  }

  void toAgreement() {
    Get.toNamed(AppRoutes.agreementPage);
  }

  void toSponsor() {
    Get.toNamed(AppRoutes.sponsorPage);
  }
}
