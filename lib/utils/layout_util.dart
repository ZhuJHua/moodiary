import 'package:flutter/services.dart';
import 'package:mood_diary/common/values/size.dart';
import 'package:refreshed/refreshed.dart';

class LayoutUtil {
  //获取设备类型
  static ScreenSize getSize() {
    var deviceWidth = Get.size.shortestSide;
    if (deviceWidth > 900) return ScreenSize.desktop;
    if (deviceWidth > 600) return ScreenSize.tablet;
    if (deviceWidth > 300) return ScreenSize.handset;
    return ScreenSize.watch;
  }

  //获取方向
  static bool isLandSpace() {
    return Get.size.aspectRatio >= 1.0;
  }

  static List<DeviceOrientation> getOrientation() {
    return switch (getSize()) {
      //手机只能竖屏
      ScreenSize.handset => [DeviceOrientation.portraitUp],
      ScreenSize.tablet => [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ],
      ScreenSize.watch => [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown
        ],
      ScreenSize.desktop => [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ],
    };
  }
}
