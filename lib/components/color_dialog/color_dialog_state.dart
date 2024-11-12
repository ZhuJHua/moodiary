import 'package:flutter/material.dart';
import 'package:mood_diary/utils/utils.dart';

class ColorDialogState {
  bool supportDynamic = Utils().prefUtil.getValue<bool>('supportDynamicColor')!;
  int currentColor = Utils().prefUtil.getValue<int>('color')!;

  Color? systemColor;

  ColorDialogState();
}
