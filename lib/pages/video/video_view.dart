import 'dart:io';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/utils/media_util.dart';

import 'video_logic.dart';

Future<T?> showVideoView<T>(
  BuildContext context,
  List<String> videoPathList,
  int initialIndex, {
  required String heroTagPrefix,
}) async {
  return await context.pushTransparentRoute(
    VideoPage(
      videoPathList: videoPathList,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
    ),
  );
}

class VideoPage extends StatelessWidget {
  final List<String> _videoPathList;
  final int _initialIndex;

  final String _heroTagPrefix;

  String get _tag => Object.hash(_videoPathList, _initialIndex).toString();

  const VideoPage({
    super.key,
    required List<String> videoPathList,
    required int initialIndex,
    required String heroTagPrefix,
  }) : _videoPathList = videoPathList,
       _initialIndex = initialIndex,
       _heroTagPrefix = heroTagPrefix;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(
      VideoLogic(videoPathList: _videoPathList, initialIndex: _initialIndex),
      tag: _tag,
    );
    final state = Bind.find<VideoLogic>(tag: _tag).state;

    Widget buildCustomTheme({required Widget child}) {
      if (Platform.isAndroid || Platform.isIOS) {
        return MaterialVideoControlsTheme(
          normal: kDefaultMaterialVideoControlsThemeData.copyWith(
            seekBarPositionColor: context.theme.colorScheme.primary,
            seekBarThumbColor: context.theme.colorScheme.primary,
          ),
          fullscreen: kDefaultMaterialVideoControlsThemeDataFullscreen.copyWith(
            seekBarPositionColor: context.theme.colorScheme.primary,
            seekBarThumbColor: context.theme.colorScheme.primary,
          ),
          child: child,
        );
      } else {
        return MaterialDesktopVideoControlsTheme(
          normal: kDefaultMaterialDesktopVideoControlsThemeData.copyWith(
            seekBarPositionColor: context.theme.colorScheme.primary,
            seekBarThumbColor: context.theme.colorScheme.primary,
          ),
          fullscreen: kDefaultMaterialDesktopVideoControlsThemeData.copyWith(
            seekBarPositionColor: context.theme.colorScheme.primary,
            seekBarThumbColor: context.theme.colorScheme.primary,
          ),
          child: child,
        );
      }
    }

    return GetBuilder<VideoLogic>(
      tag: _tag,
      assignId: true,
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
            actions: [
              IconButton(
                onPressed: () {
                  MediaUtil.saveToGallery(
                    path: state.videoPathList[state.videoIndex.value],
                    type: MediaType.video,
                  );
                },
                icon: const Icon(Icons.save_alt),
              ),
            ],
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 56.0),
            child: buildCustomTheme(
              child: Hero(
                tag: '$_heroTagPrefix${state.videoIndex.value}',
                child: Video(
                  controller: logic.videoController,
                  controls: AdaptiveVideoControls,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
