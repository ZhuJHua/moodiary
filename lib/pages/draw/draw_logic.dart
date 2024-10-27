import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/edit/edit_logic.dart';

import 'draw_state.dart';

class DrawLogic extends GetxController {
  final DrawState state = DrawState();
  late DrawingController drawingController = DrawingController()..setStyle(color: state.pickerColor);
  late final editLogic = Bind.find<EditLogic>();

  @override
  void onClose() {
    drawingController.dispose();
    super.onClose();
  }

  Future<void> getImageData() async {
    var data = await drawingController.getImageData();
    var image = data!.buffer.asUint8List();
    editLogic.pickDraw(image);
    Get.backLegacy();
  }

  Future<void> showColorPicker() async {
    await showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: const Text('选择颜色'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: state.pickerColor,
                onColorChanged: (Color value) {
                  state.pickerColor = value;
                  update();
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Get.backLegacy();
                  },
                  child: const Text('取消')),
              TextButton(
                  onPressed: () {
                    Get.backLegacy();
                    setColor();
                  },
                  child: const Text('确认'))
            ],
          );
        });
  }

  void setColor() {
    drawingController.setStyle(color: state.pickerColor);
    update();
  }

  Future<void> showCheck() async {
    await showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('确认保存吗'),
            actions: [
              TextButton(
                  onPressed: () {
                    Get.backLegacy();
                  },
                  child: const Text('取消')),
              TextButton(
                  onPressed: () async {
                    Get.backLegacy();
                    await getImageData();
                  },
                  child: const Text('确认'))
            ],
          );
        });
  }
}
