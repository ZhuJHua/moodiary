import 'package:get/get.dart';

class VideoPlayerState {
  late String videoPath;

  RxBool isInitialized = false.obs;

  VideoPlayerState();
}
