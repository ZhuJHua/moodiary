import 'dart:io';

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

    Widget buildCustomTheme({required Widget child}) {
      if (Platform.isAndroid || Platform.isIOS) {
        return MaterialVideoControlsTheme(
          normal: kDefaultMaterialVideoControlsThemeData.copyWith(
            seekBarPositionColor: colorScheme.primary,
            seekBarThumbColor: colorScheme.primary,
          ),
          fullscreen: kDefaultMaterialVideoControlsThemeDataFullscreen.copyWith(
            seekBarPositionColor: colorScheme.primary,
            seekBarThumbColor: colorScheme.primary,
          ),
          child: child,
        );
      } else {
        return MaterialDesktopVideoControlsTheme(
          normal: kDefaultMaterialDesktopVideoControlsThemeData.copyWith(
            seekBarPositionColor: colorScheme.primary,
            seekBarThumbColor: colorScheme.primary,
          ),
          fullscreen: kDefaultMaterialDesktopVideoControlsThemeData.copyWith(
            seekBarPositionColor: colorScheme.primary,
            seekBarThumbColor: colorScheme.primary,
          ),
          child: child,
        );
      }
    }

    return GetBuilder<VideoLogic>(
      builder: (_) {
        return Scaffold(
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
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 56.0),
            child: buildCustomTheme(
              child: Video(
                controller: logic.videoController,
                controls: AdaptiveVideoControls,
                alignment: Alignment.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
