import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:get/get.dart';

import 'draw_logic.dart';

class DrawPage extends StatelessWidget {
  const DrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DrawLogic>();
    final state = Bind.find<DrawLogic>().state;
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    var drawWidth = min(300.0, size.width * 0.8);
    return Scaffold(
      appBar: AppBar(
        title: const Text('画板'),
      ),
      body: Center(
        child: Container(
          width: drawWidth,
          height: (drawWidth * 1.618) + 96,
          decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(
                  strokeAlign: BorderSide.strokeAlignOutside,
                  color: colorScheme.primary,
                  width: 4.0))),
          child: GetBuilder<DrawLogic>(builder: (_) {
            return DrawingBoard(
              controller: logic.drawingController,
              background: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                width: drawWidth,
                height: drawWidth * 1.618,
              ),
              boardClipBehavior: Clip.none,
              boardConstrained: true,
              defaultToolsBuilder: (Type t, _) {
                return DrawingBoard.defaultTools(t, logic.drawingController)
                  ..insert(
                      0,
                      DefToolItem(
                        icon: Icons.circle,
                        color: state.pickerColor,
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('选择颜色'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: state.pickerColor,
                                      onColorChanged: (Color value) {
                                        logic.pickColor(value);
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
                                          logic.setColor();
                                        },
                                        child: const Text('确认'))
                                  ],
                                );
                              });
                        },
                        isActive: false,
                      ));
              },
              showDefaultActions: true,
              showDefaultTools: true,
              boardScaleEnabled: false,
              boardPanEnabled: false,
            );
          }),
        ),
      ),
      persistentFooterButtons: [
        FloatingActionButton(
          onPressed: () {
            showDialog(
                context: context,
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
                            await logic.getImageData();
                          },
                          child: const Text('确认'))
                    ],
                  );
                });
          },
          child: const Icon(Icons.check),
        )
      ],
    );
  }
}
