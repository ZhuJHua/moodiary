import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

class NoticeUtil {
  final _fToast = FToast();

  NoticeUtil() {
    _fToast.init(Get.overlayContext!);
  }

  void showToast(String message) async {
    final colorScheme = Theme.of(Get.context!).colorScheme;
    _fToast.showToast(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            color: colorScheme.secondaryContainer.withAlpha((255 * 0.95).toInt()),
          ),
          child: Text(
            message,
            style: TextStyle(fontSize: 16.0, color: colorScheme.onSecondaryContainer),
          ),
        ),
        gravity: ToastGravity.BOTTOM,
        isDismissable: true);
  }

  void showBug() async {
    final colorScheme = Theme.of(Get.context!).colorScheme;
    _fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: colorScheme.errorContainer.withAlpha((255 * 0.95).toInt()),
        ),
        child: Text(
          '出错了，请联系开发者！',
          style: TextStyle(fontSize: 16.0, color: colorScheme.onErrorContainer),
        ),
      ),
      gravity: ToastGravity.CENTER,
      isDismissable: false,
      toastDuration: const Duration(seconds: 4),
    );
  }
}
