import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'share_state.dart';

class ShareLogic extends GetxController {
  final ShareState state = ShareState();

  @override
  void onInit() {
    state.diary = Get.arguments;
    super.onInit();
  }

  Future<Uint8List> captureWidget() async {
    var boundary =
        state.key.currentContext?.findRenderObject() as RenderRepaintBoundary;
    var pixelRatio = MediaQuery.devicePixelRatioOf(Get.context!);
    var image = await boundary.toImage(pixelRatio: pixelRatio);
    var data = await image.toByteData(format: ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> share() async {
    var name = 'screenshot-${const Uuid().v7()}.png';
    File(FileUtil.getCachePath(name)).writeAsBytes(await captureWidget());
    await Share.shareXFiles([XFile(FileUtil.getCachePath(name))]);
  }
}
