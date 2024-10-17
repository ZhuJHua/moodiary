import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_logic.dart';

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<VideoLogic>();
    final state = Bind.find<VideoLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return GetBuilder<VideoLogic>(
      assignId: true,
      init: logic,
      builder: (logic) {
        return MaterialVideoControlsTheme(
          normal: MaterialVideoControlsThemeData(
            seekBarPositionColor: colorScheme.primary,
            seekBarThumbColor: colorScheme.primary,
            padding: const EdgeInsets.only(bottom: 56.0),
          ),
          fullscreen: MaterialVideoControlsThemeData(
              seekBarPositionColor: colorScheme.primary,
              seekBarThumbColor: colorScheme.primary,
              padding: const EdgeInsets.only(bottom: 24.0)),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Obx(() {
                return Text(
                  '${state.videoIndex.value + 1}/${state.videoPathList.length}',
                  style: const TextStyle(color: Colors.white),
                );
              }),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Video(
              controller: logic.videoController,
            ),
          ),
        );
      },
    );
  }
}
