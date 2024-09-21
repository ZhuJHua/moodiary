import 'package:get/get.dart';

class WaveFormState {
  late double barWidth;
  late double spaceWidth;
  late RxList<double> amplitudes;
  WaveFormState() {
    amplitudes = <double>[].obs;
    barWidth=2.0;
    spaceWidth=2.0;
    ///Initialize variables
  }
}
