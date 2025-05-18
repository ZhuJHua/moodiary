import 'package:get/get.dart';

class VideoState {
  //视频路径
  late List<String> videoPathList;

  //当前位置
  late Rx<int> videoIndex;

  RxBool isInitialized = false.obs;

  VideoState();
}
