import 'package:get/get.dart';

class HomeState {
  //fab展开状态
  late RxBool isFabExpanded;

  //导航栏index
  late RxInt navigatorIndex;

  late double navigatorBarHeight;

  HomeState() {
    isFabExpanded = false.obs;

    navigatorIndex = 0.obs;

    navigatorBarHeight = 56.0;

    ///Initialize variables
  }
}
