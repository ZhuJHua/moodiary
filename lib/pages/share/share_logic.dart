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
    final boundary =
        state.key.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final pixelRatio = MediaQuery.devicePixelRatioOf(Get.context!);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> share() async {
    final name = 'screenshot-${const Uuid().v7()}.png';
    File(FileUtil.getCachePath(name)).writeAsBytes(await captureWidget());
    await Share.shareXFiles([XFile(FileUtil.getCachePath(name))]);
  }
}
