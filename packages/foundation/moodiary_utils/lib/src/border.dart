import 'package:flutter/cupertino.dart';

class AppBorderRadius {
  static const BorderRadius smallBorderRadius = .all(.circular(8.0));
  static const BorderRadius mediumBorderRadius = .all(.circular(12.0));
  static const BorderRadius largeBorderRadius = .all(.circular(16.0));

  /// 弹窗一类的大面积浮层。比 [largeBorderRadius] 更圆，用来替代 M3 弹窗默认的 28
  /// 以及散落在图谱卡（22）、分享卡（18）上的孤儿值。
  static const BorderRadius xLargeBorderRadius = .all(.circular(24.0));
}
