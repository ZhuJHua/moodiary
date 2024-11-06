import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'audio_player_logic.dart';

class AudioPlayerComponent extends StatelessWidget {
  const AudioPlayerComponent({super.key, required this.path, this.isEdit = false});

  final String path;

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(AudioPlayerLogic(), tag: path);
    final state = Bind.find<AudioPlayerLogic>(tag: path).state;

    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<AudioPlayerLogic>(
      
      tag: path,
      
      initState: (_) async {
        await logic.initAudioPlayer(path);
      },
      builder: (_) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card.filled(
            color: colorScheme.secondaryContainer,
            child: Padding(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() {
                          return Slider(
                            value: state.totalDuration.value != Duration.zero
                                ? ((state.currentDuration.value.inMilliseconds /
                                        state.totalDuration.value.inMilliseconds)
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
                        logic.editLogic.deleteAudio(path);
                      },
                      icon: const Icon(Icons.cancel),
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    )
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
