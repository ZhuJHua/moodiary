import 'dart:math';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'draw_logic.dart';

class DrawPage extends StatelessWidget {
  const DrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DrawLogic>();
    final state = Bind.find<DrawLogic>().state;
    final size = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final drawWidth = min(300.0, size.width * 0.8);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editPickImageFromDraw),
        leading: const PageBackButton(),
      ),
      resizeToAvoidBottomInset: false,
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
                        onTap: () async {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(l10n.drawPickColor),
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
                                          Navigator.pop(context);
                                        },
                                        child: Text(l10n.cancel)),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          logic.setColor();
                                        },
                                        child: Text(l10n.ok))
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
      persistentFooterAlignment: AlignmentDirectional.center,
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FilledButton(
            onPressed: () async {
              final res = await showOkCancelAlertDialog(
                  context: context,
                  title: l10n.hint,
                  message: l10n.sureToSave,
                  style: AdaptiveStyle.material);
              if (res == OkCancelResult.ok && context.mounted) {
                await logic.getImageData(context);
              }
            },
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }
}
