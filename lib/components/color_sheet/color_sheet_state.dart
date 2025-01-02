import 'dart:ui';

import '../../utils/data/pref.dart';

class ColorSheetState {
  bool supportDynamic = PrefUtil.getValue<bool>('supportDynamicColor')!;
  int currentColor = PrefUtil.getValue<int>('color')!;

  Color? systemColor;

  ColorSheetState();
}
