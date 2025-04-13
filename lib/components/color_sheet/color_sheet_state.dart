import 'package:moodiary/persistence/pref.dart';

class ColorSheetState {
  int currentColor = PrefUtil.getValue<int>('color')!;

  ColorSheetState();
}
