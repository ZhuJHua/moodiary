import 'dart:async';
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
    useRootNavigator: false,
  );

  Completer<void>? _initCompleter;

  VideoPlayerLogic({required String videoPath}) {
    state.videoPath = videoPath;
  }

  @override
  void onReady() async {
    _initCompleter = Completer<void>();
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!(_initCompleter?.isCompleted ?? true)) {
        await videoPlayerController.initialize();
        state.isInitialized.value = true;
        _initCompleter?.complete();
      }
    });

    super.onReady();
  }

  void cancelInitialization() {
    if (!(_initCompleter?.isCompleted ?? true)) {
      _initCompleter?.complete();
      state.isInitialized.value = false;
    }
  }

  @override
  void onClose() async {
    cancelInitialization();
    await videoPlayerController.dispose();
    chewieController.dispose();
    super.onClose();
  }
}
