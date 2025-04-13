import 'package:get/get.dart';

class RecordSheetState {
  late Rx<Duration> durationTime;
  late RxBool isRecording;
  late RxBool isStarted;
  late String fileName;
  late RxDouble height;

  late double maxWidth;
  late bool isStop;

  RecordSheetState() {
    isRecording = false.obs;
    isStarted = false.obs;
    fileName = '';
    height = .0.obs;
    isStop = false;
    durationTime = const Duration().obs;

    ///Initialize variables
  }
}
