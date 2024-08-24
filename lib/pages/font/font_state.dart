import 'package:mood_diary/utils/utils.dart';

class FontState {
  late double fontScale;

  FontState() {
    fontScale = (Utils().prefUtil.getValue<double>('fontScale'))!;

    ///Initialize variables
  }
}
