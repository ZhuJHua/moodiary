import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:moodiary/pages/edit/edit_logic.dart';
import 'package:refreshed/refreshed.dart';

import 'draw_state.dart';

class DrawLogic extends GetxController {
  final DrawState state = DrawState();
  late DrawingController drawingController = DrawingController()
    ..setStyle(color: state.pickerColor);
  late final editLogic = Bind.find<EditLogic>();

  @override
  void onClose() {
    drawingController.dispose();
    super.onClose();
  }

  Future<void> getImageData() async {
    var data = await drawingController.getImageData();
    var image = data!.buffer.asUint8List();
    Get.back();
    editLogic.pickDraw(image);
  }

  void pickColor(Color color) {
    state.pickerColor = color;
    update();
  }

  void setColor() {
    drawingController.setStyle(color: state.pickerColor);
  }
}
