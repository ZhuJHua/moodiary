import 'package:get/get.dart';

import 'image_state.dart';

class ImageLogic extends GetxController {
  final ImageState state = ImageState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  void changePage(int index) {
    state.imageIndex = index;
    update();
  }
}
