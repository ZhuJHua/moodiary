import 'package:get/get.dart';

class RecordSheetState {
  late RxList<double> amplitudes;
  late Rx<Duration> durationTime;
  late RxBool isRecording;
  late RxBool isStarted;
  late String fileName;
  late RxDouble height;

  late double maxWidth;
  late bool isStop;

  late double barWidth;
  late double spaceWidth;

  RecordSheetState() {
    amplitudes = <double>[].obs;
    isRecording = false.obs;
    isStarted = false.obs;
    fileName = '';
    height = .0.obs;
    isStop = false;
    durationTime = const Duration().obs;
    barWidth = 2.0;
    spaceWidth = 2.0;

    ///Initialize variables
  }
}
