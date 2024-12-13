import 'package:flutter/material.dart';

import '../../utils/data/pref.dart';

class ColorDialogState {
  bool supportDynamic = PrefUtil.getValue<bool>('supportDynamicColor')!;
  int currentColor = PrefUtil.getValue<int>('color')!;

  Color? systemColor;

  ColorDialogState();
}
