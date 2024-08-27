import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

class NoticeUtil {
  void showToast(String message) async {
    final colorScheme = Theme.of(Get.context!).colorScheme;

    if (Platform.isWindows) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        backgroundColor: colorScheme.secondaryContainer,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      Fluttertoast.cancel();
      Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.SNACKBAR,
          timeInSecForIosWeb: 1,
          backgroundColor: colorScheme.secondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
          fontSize: 16.0);
    }
  }

  void showBug(message, {required Object error, StackTrace? stackTrace}) {
    // final colorScheme = Theme.of(Get.context!).colorScheme;
    // ScaffoldMessenger.of(Get.context!).clearSnackBars();
    // ScaffoldMessenger.of(Get.context!).showSnackBar(
    //   SnackBar(
    //     content: Column(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Text(
    //           '出错了！请截图联系开发者。$message',
    //           style: TextStyle(color: colorScheme.onErrorContainer),
    //         ),
    //         Text(
    //           error.toString(),
    //           style: TextStyle(color: colorScheme.onErrorContainer),
    //         ),
    //         Text(stackTrace?.toString() ?? '', style: TextStyle(color: colorScheme.onErrorContainer)),
    //       ],
    //     ),
    //     behavior: SnackBarBehavior.floating,
    //     duration: const Duration(seconds: 20),
    //     backgroundColor: colorScheme.errorContainer,
    //     showCloseIcon: true,
    //   ),
    // );
  }
}
