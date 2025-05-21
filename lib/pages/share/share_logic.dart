import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/file_util.dart';
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

  Future<Uint8List> _captureWidget(BuildContext context) async {
    final boundary =
        state.key.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> share(BuildContext context) async {
    final name = 'screenshot-${const Uuid().v7()}.png';
    await File(
      FileUtil.getCachePath(name),
    ).writeAsBytes(await _captureWidget(context));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(FileUtil.getCachePath(name))]),
    );
  }
}
