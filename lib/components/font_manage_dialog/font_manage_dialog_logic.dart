import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/log_util.dart';
import 'package:path/path.dart';

class FontManageDialogLogic extends GetxController {
  late final TextEditingController fontNameController =
      TextEditingController(text: basename(currentFontPath).split('.ttf')[0]);

  final String currentFontPath;

  FontManageDialogLogic({required this.currentFontPath});

  @override
  void onReady() {
    LogUtil.printInfo(currentFontPath);
    super.onReady();
  }

  @override
  void onClose() {
    fontNameController.dispose();
    super.onClose();
  }
}
