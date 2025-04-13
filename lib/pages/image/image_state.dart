import 'package:get/get.dart';

class ImageState {
  late List<String> imagePathList;

  //当前图片的的位置
  late RxInt imageIndex;

  late RxDouble opacity = 0.9.obs;

  ImageState();
}
