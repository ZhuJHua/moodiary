import 'package:get/get.dart';

import 'image_state.dart';

class ImageLogic extends GetxController {
  final ImageState state = ImageState();

  void changePage(int index) {
    state.imageIndex = index;
    update();
  }
}
