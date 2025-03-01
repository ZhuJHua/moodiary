import 'package:moodiary/presentation/pref.dart';

class ColorSheetState {
  int currentColor = PrefUtil.getValue<int>('color')!;

  ColorSheetState();
}
