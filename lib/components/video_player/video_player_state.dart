import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

class VideoPlayerState {
  late Playable playable;

  late String videoPath;

  RxBool isInitialized = false.obs;

  VideoPlayerState() {
    ///Initialize variables
  }
}
