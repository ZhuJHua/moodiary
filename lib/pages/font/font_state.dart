import '../../utils/data/pref.dart';

class FontState {
  late double fontScale;

  FontState() {
    fontScale = (PrefUtil.getValue<double>('fontScale'))!;

    ///Initialize variables
  }
}
