import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/size.dart';

class LayoutUtil {
  //获取设备类型
  ScreenSize getSize(deviceWidth) {
    if (deviceWidth > 900) return ScreenSize.desktop;
    if (deviceWidth > 600) return ScreenSize.tablet;
    if (deviceWidth > 300) return ScreenSize.handset;
    return ScreenSize.watch;
  }

  //获取方向
  bool isLandSpace() {
    return MediaQuery.sizeOf(Get.context!).aspectRatio >= 1.0;
  }
}
