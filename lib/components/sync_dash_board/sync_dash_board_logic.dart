import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/sync_dash_board/sync_dash_board_state.dart';

import '../../utils/webdav_util.dart';

class SyncDashBoardLogic extends GetxController {
  final SyncDashBoardState state = SyncDashBoardState();
  late final PageController pageController;

  @override
  void onReady() async {
    if ((await WebDavUtil().checkConnectivity()) == false) {
      pageController = PageController(initialPage: 1);
    } else {
      pageController = PageController(initialPage: 0);
    }
    state.isFetching = false;
    update();
    super.onReady();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
