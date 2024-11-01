import 'package:get/get.dart';

class HomeState {
  //fab展开状态
  late RxBool isFabExpanded;

  //bar隐藏状态

  late RxBool isBarHidden;

  //导航栏index
  late RxInt navigatorIndex;

  late double navigatorBarHeight;

  //一言
  late RxString hitokoto;

  HomeState() {
    isFabExpanded = false.obs;

    isBarHidden = false.obs;

    navigatorIndex = 0.obs;

    navigatorBarHeight = 80.0;
    hitokoto = ''.obs;

    ///Initialize variables
  }
}
