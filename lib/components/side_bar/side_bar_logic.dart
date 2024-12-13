import 'dart:async';

import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/cache_util.dart';
import 'package:mood_diary/utils/package_util.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/data/pref.dart';
import 'side_bar_state.dart';

class SideBarLogic extends GetxController {
  final SideBarState state = SideBarState();

  late HomeLogic homeLogic = Bind.find<HomeLogic>();

  @override
  void onReady() {
    getHitokoto();
    getImage();
    getInfo();
    // getWeather();
    super.onReady();
  }

  // Future<void> getWeather() async {
  //   var key = PrefUtil.getValue<String>('qweatherKey');
  //   if (state.getWeather && key != null) {
  //     state.weatherResponse.value =
  //         await Utils().cacheUtil.getCacheList('weather', Api.updateWeather, maxAgeMillis: 15 * 60000) ?? [];
  //   }
  // }

  Future<void> getHitokoto() async {
    var res = await CacheUtil.getCacheList('hitokoto', Api.updateHitokoto, maxAgeMillis: 15 * 60000);
    if (res != null) {
      state.hitokoto.value = res.first;
    }
  }

  Future<void> getImage() async {
    var url = await CacheUtil.getCacheList('bingImage', Api.updateImageUrl, maxAgeMillis: 6 * 60 * 60000);
    if (url != null) {
      state.imageUrl.value = url.first;
    }
  }

  Future<void> getInfo() async {
    state.packageInfo.value = await PackageUtil.getPackageInfo();
  }

  //跳转到反馈页
  Future<void> toReportPage() async {
    var uri = Uri(scheme: 'https', host: 'support.qq.com', path: 'products/650147', queryParameters: {
      'nickname': PrefUtil.getValue<String>('uuid'),
      'avatar': 'https://txc.qq.com/static/desktop/img/products/def-product-logo.png',
      'openid': PrefUtil.getValue<String>('uuid')
    });
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  void toPrivacy() {
    Get.toNamed(AppRoutes.privacyPage);
  }

  void toAssistant() {
    Get.toNamed(AppRoutes.assistantPage);
  }
}
