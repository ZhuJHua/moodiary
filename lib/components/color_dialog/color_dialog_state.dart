import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class ColorDialogState {
  late RxBool supportDynamic;
  late RxInt currentColor;

  late Rx<Color> systemColor;

  ColorDialogState() {
    supportDynamic = Utils().prefUtil.getValue<bool>('supportDynamicColor')!.obs;
    currentColor = Utils().prefUtil.getValue<int>('color')!.obs;
    systemColor = Colors.transparent.obs;

    ///Initialize variables
  }
}
