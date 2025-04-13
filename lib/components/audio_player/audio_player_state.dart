import 'package:get/get.dart';

class AudioPlayerState {
  late String audioPath;
  late Rx<Duration> totalDuration;
  late Rx<Duration> currentDuration;
  late RxBool handleChange;

  AudioPlayerState() {
    audioPath = '';
    handleChange = false.obs;
    totalDuration = Duration.zero.obs;
    currentDuration = Duration.zero.obs;

    ///Initialize variables
  }
}
