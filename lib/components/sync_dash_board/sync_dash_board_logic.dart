import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/sync_dash_board/sync_dash_board_state.dart';
import 'package:moodiary/utils/webdav_util.dart';

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
    if (state.isFetching == false) {
      pageController.dispose();
    }
    super.onClose();
  }

  void changePage(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}
