import 'package:refreshed/refreshed.dart';

class ImageState {
  List<String> imagePathList = Get.arguments[0];

  //当前图片的的位置
  RxInt imageIndex = (Get.arguments[1] as int).obs;

  ImageState();
}
