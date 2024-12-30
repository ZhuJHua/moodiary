import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/wave_form/wave_form_view.dart';

import 'record_sheet_logic.dart';

class RecordSheetComponent extends StatelessWidget {
  const RecordSheetComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(RecordSheetLogic());
    final state = Bind.find<RecordSheetLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, constrains) {
      return GetBuilder<RecordSheetLogic>(
        assignId: true,
        initState: (_) {
          logic.initMaxWidth(constrains.maxWidth);
        },
        builder: (_) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                child: Obx(() {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    child: state.isStarted.value
                        ? const WaveFormComponent()
                        : Center(
                            child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: colorScheme.outline, width: 4.0),
                                shape: BoxShape.circle),
                            child: IconButton(
                                onPressed: () {
                                  logic.startRecorder();
                                },
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.circle,
                                  size: 48,
                                  color: Colors.redAccent,
                                )),
                          )),
                  );
                }),
              ),
              Obx(() {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: state.height.value,
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: state.height.value,
                    alignment: Alignment.center,
                    child: state.isStarted.value
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            key: const ValueKey('playButton'),
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Obx(() {
                                    return Text(state.durationTime.value
                                        .toString()
                                        .split('.')[0]);
                                  }),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                      onPressed: () {
                                        logic.cancelRecorder();
                                      },
                                      child: const Text('取消')),
                                  FilledButton(
                                      onPressed: () {
                                        state.isRecording.value
                                            ? logic.pauseRecorder()
                                            : logic.resumeRecorder();
                                      },
                                      child: AnimatedIcon(
                                        icon: AnimatedIcons.play_pause,
                                        progress: logic.animationController,
                                      )),
                                  TextButton(
                                      onPressed: () {
                                        logic.stopRecorder();
                                      },
                                      child: const Text('保存')),
                                ],
                              )
                            ],
                          )
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      );
    });
  }
}
