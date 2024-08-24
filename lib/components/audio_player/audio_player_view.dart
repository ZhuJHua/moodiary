import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'audio_player_logic.dart';

class AudioPlayerComponent extends StatelessWidget {
  const AudioPlayerComponent({super.key, required this.path, required this.index, this.isEdit = false});

  final String path;
  final String index;

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(AudioPlayerLogic(), tag: index);
    final state = Bind.find<AudioPlayerLogic>(tag: index).state;

    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<AudioPlayerLogic>(
      init: logic,
      tag: index,
      assignId: true,
      initState: (_) async {
        await logic.initAudioPlayer(path);
      },
      builder: (logic) {
        return Container(
          decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(8.0)),
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton.filled(
                  onPressed: () {
                    logic.audioPlayer.state == PlayerState.playing ? logic.pause() : logic.play(path);
                  },
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: logic.animationController,
                    color: colorScheme.onPrimary,
                  )),
              Expanded(
                child: Column(
                  children: [
                    Obx(() {
                      return Slider(
                        value: state.totalDuration.value != Duration.zero
                            ? ((state.currentDuration.value.inMilliseconds / state.totalDuration.value.inMilliseconds)
                                .clamp(0, 1))
                            : 0,
                        onChangeEnd: (value) {
                          logic.to(value);
                        },
                        onChanged: (double value) {
                          logic.changeValue(value);
                        },
                        inactiveColor: colorScheme.outline,
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(() {
                            return Text(
                              state.totalDuration.value.toString().split('.')[0].padLeft(8, '0'),
                              style: TextStyle(color: colorScheme.onSecondaryContainer),
                            );
                          }),
                          Obx(() {
                            return Text(
                              state.currentDuration.value.toString().split('.')[0].padLeft(8, '0'),
                              style: TextStyle(color: colorScheme.onSecondaryContainer),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isEdit) ...[
                IconButton(
                  onPressed: () {
                    logic.editLogic.deleteAudio(int.parse(index));
                  },
                  icon: const Icon(Icons.cancel),
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                )
              ]
            ],
          ),
        );
      },
    );
  }
}
