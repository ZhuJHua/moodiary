import 'package:refreshed/refreshed.dart';

class WaveFormLogic extends GetxController {
  late double barWidth = 2.0;
  late double spaceWidth = 2.0;
  late RxList<double> amplitudes = <double>[].obs;

  void maxLengthAdd(value, maxWidth) {
    if (amplitudes.length > maxWidth ~/ (barWidth + spaceWidth)) {
      amplitudes.removeAt(0);
    }
    amplitudes.add(value);
  }
}
