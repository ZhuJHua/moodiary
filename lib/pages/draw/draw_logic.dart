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

  Future<void> getImageData(BuildContext context) async {
    final data = await drawingController.getImageData();
    final image = data!.buffer.asUint8List();
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) await editLogic.pickDraw(image, context);
  }

  void pickColor(Color color) {
    state.pickerColor = color;
    update();
  }

  void setColor() {
    drawingController.setStyle(color: state.pickerColor);
  }
}
