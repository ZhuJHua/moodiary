import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'share_state.dart';

class ShareLogic extends GetxController {
  final ShareState state = ShareState();

  @override
  void onInit() {
    // TODO: implement onInit
    state.diary = Get.arguments;
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<Uint8List> captureWidget() async {
    var boundary = state.key.currentContext?.findRenderObject() as RenderRepaintBoundary;
    var pixelRatio = MediaQuery.devicePixelRatioOf(Get.context!);
    var image = await boundary.toImage(pixelRatio: pixelRatio);
    var data = await image.toByteData(format: ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> share() async {
    await Share.shareXFiles([XFile.fromData(await captureWidget(), mimeType: 'image/png')]);
  }
}
