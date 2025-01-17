import 'package:refreshed/refreshed.dart';

class WebViewState {
  RxDouble progress = 0.0.obs;
  String url = Get.arguments[0];
  String title = Get.arguments[1];

  RxBool isTop = false.obs;
  RxBool isRight = true.obs;
}
