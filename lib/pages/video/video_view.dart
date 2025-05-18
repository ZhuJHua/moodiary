import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/loading.dart';

import 'video_logic.dart';

Future<T?> showVideoView<T>(
  BuildContext context,
  List<String> videoPathList,
  int initialIndex,
) async {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) {
        return VideoPage(
          videoPathList: videoPathList,
          initialIndex: initialIndex,
        );
      },
    ),
  );
}

class VideoPage extends StatelessWidget {
  final List<String> _videoPathList;
  final int _initialIndex;

  String get _tag => Object.hash(_videoPathList, _initialIndex).toString();

  const VideoPage({
    super.key,
    required List<String> videoPathList,
    required int initialIndex,
  }) : _videoPathList = videoPathList,
       _initialIndex = initialIndex;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(
      VideoLogic(videoPathList: _videoPathList, initialIndex: _initialIndex),
      tag: _tag,
    );
    final state = Bind.find<VideoLogic>(tag: _tag).state;

    return GetBuilder<VideoLogic>(
      tag: _tag,
      assignId: true,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: Durations.medium2,
                  child: Obx(() {
                    return state.isInitialized.value
                        ? Chewie(controller: logic.chewieController)
                        : const Center(
                          child: MoodiaryLoading(color: Colors.white70),
                        );
                  }),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: PageBackButton(
                    onBack: () => Navigator.pop(context),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
