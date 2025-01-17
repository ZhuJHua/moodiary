import 'package:device_info_plus/device_info_plus.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/package_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_state.dart';

class AboutLogic extends GetxController {
  final AboutState state = AboutState();

  @override
  void onReady() async {
    await getInfo();
    super.onReady();
  }

  Future<void> getInfo() async {
    var packageInfo = await PackageUtil.getPackageInfo();
    var deviceInfo = await PackageUtil.getInfo();
    if (deviceInfo is AndroidDeviceInfo) {
      state.systemVersion = 'Android ${deviceInfo.version.release}';
    } else if (deviceInfo is IosDeviceInfo) {
      state.systemVersion =
          '${deviceInfo.systemName} ${deviceInfo.systemVersion}';
    } else if (deviceInfo is WindowsDeviceInfo) {
      state.systemVersion = 'Windows ${deviceInfo.majorVersion}';
    } else if (deviceInfo is MacOsDeviceInfo) {
      state.systemVersion = 'MacOS ${deviceInfo.osRelease} ';
    }

    state.appName = packageInfo.appName;
    state.appVersion = '${packageInfo.version}(${packageInfo.buildNumber})';
    update();
  }

  //跳转到反馈页
  Future<void> toReportPage() async {
    await Get.toNamed(AppRoutes.webViewPage,
        arguments: ['https://answer.moodiary.net', '反馈']);
    //await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  //跳转至源代码
  Future<void> toSource() async {
    var uri = Uri(
      scheme: 'https',
      host: 'github.com',
      path: 'ZhuJHua/moodiary',
    );
    await launchUrl(uri, mode: LaunchMode.platformDefault);
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
