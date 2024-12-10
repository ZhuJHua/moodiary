import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import 'video_player_state.dart';

class VideoPlayerLogic extends GetxController {
  final VideoPlayerState state = VideoPlayerState();

  late final videoPlayerController = VideoPlayerController.file(File(state.videoPath));
  late final chewieController = ChewieController(
    videoPlayerController: videoPlayerController,
    aspectRatio: 16 / 9,
    useRootNavigator: false,
  );

  VideoPlayerLogic({required String videoPath}) {
    state.videoPath = videoPath;
  }

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() async {
    await videoPlayerController.initialize();
    update();
    super.onReady();
  }

  @override
  void onClose() {
    videoPlayerController.dispose();
    chewieController.dispose();
    super.onClose();
  }
}
