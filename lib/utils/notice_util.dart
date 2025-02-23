import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:refreshed/refreshed.dart';

class NoticeUtil {
  static final _fToast = FToast()..init(Get.overlayContext!);

  static void showToast(String message) {
    late final colorScheme = Theme.of(Get.context!).colorScheme;
    _fToast.removeCustomToast();
    _fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: colorScheme.primaryContainer.withValues(alpha: 0.8),
        ),
        child: Text(
          message,
          style:
              TextStyle(fontSize: 16.0, color: colorScheme.onPrimaryContainer),
        ),
      ),
      gravity: ToastGravity.CENTER,
    );
  }

  static void showLoading({String message = '加载中'}) {
    _fToast.removeCustomToast();
    _fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: Colors.black.withAlpha(200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(width: 16.0),
            Text(
              message,
              style: const TextStyle(fontSize: 16.0, color: Colors.white),
            ),
          ],
        ),
      ),
      gravity: ToastGravity.CENTER,
      toastDuration: const Duration(seconds: 10),
    );
  }

  static void showBug({required String message}) {
    if(kDebugMode) return;
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
          style: const TextStyle(fontSize: 16.0, color: Colors.white),
        ),
      ),
      gravity: ToastGravity.CENTER,
      toastDuration: const Duration(seconds: 2),
    );
  }
}
