import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

class NoticeUtil {
  final _fToast = FToast();

  NoticeUtil() {
    _fToast.init(Get.overlayContext!);
  }

  void showToast(String message) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      late final colorScheme = Theme.of(Get.context!).colorScheme;
      _fToast.removeCustomToast();
      _fToast.showToast(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: colorScheme.primaryContainer.withAlpha(240),
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 16.0, color: colorScheme.onPrimaryContainer),
            ),
          ),
          gravity: ToastGravity.CENTER,
          isDismissable: true);
    });
  }

  void showBug({required String message}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fToast.removeCustomToast();
      _fToast.showToast(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            color: Colors.redAccent.withAlpha((240)),
          ),
          child: Text(
            message,
            style: TextStyle(fontSize: 16.0, color: Colors.white),
          ),
        ),
        gravity: ToastGravity.CENTER,
        isDismissable: false,
        toastDuration: const Duration(seconds: 2),
      );
    });
  }
}
