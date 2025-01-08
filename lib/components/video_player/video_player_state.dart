import 'package:refreshed/refreshed.dart';

class VideoPlayerState {
  late String videoPath;

  RxBool isInitialized = false.obs;

  VideoPlayerState();
}
