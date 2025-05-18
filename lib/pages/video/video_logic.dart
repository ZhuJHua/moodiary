import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/media_type.dart';
import 'package:moodiary/components/base/sheet.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:video_player/video_player.dart';

import 'video_state.dart';

class VideoLogic extends GetxController {
  final VideoState state = VideoState();

  late VideoPlayerController _videoPlayerController;

  late ChewieController chewieController;

  VideoLogic({required List<String> videoPathList, required int initialIndex}) {
    state.videoPathList = videoPathList;
    state.videoIndex = initialIndex.obs;
  }

  double get aspectRatio => _videoPlayerController.value.aspectRatio;
  Completer<void>? _initCompleter;

  @override
  void onInit() {
    _initCompleter = Completer<void>();
    Future.delayed(const Duration(milliseconds: 300), () async {
      await initVideo();
      _initCompleter?.complete();
    });

    super.onInit();
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
    await _videoPlayerController.dispose();
    chewieController.dispose();
    super.onClose();
  }

  Future<void> initVideo() async {
    _videoPlayerController = VideoPlayerController.file(
      File(state.videoPathList[state.videoIndex.value]),
    );
    chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      allowPlaybackSpeedChanging: false,
      optionsTranslation: OptionsTranslation(playbackSpeedButtonText: '播放速度'),
      optionsBuilder: (context, options) async {
        await showFloatingModalBottomSheet(
          context: context,
          builder: (context) {
            return ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option.title),
                  leading: Icon(option.iconData),
                  onTap: () {
                    option.onTap.call(context);
                  },
                );
              },
              itemCount: options.length,
            );
          },
        );
      },
      additionalOptions: (context) {
        return [
          OptionItem(
            onTap: (context) {
              MediaUtil.saveToGallery(
                path: state.videoPathList[state.videoIndex.value],
                type: MediaType.video,
              );
            },
            iconData: Icons.save_alt_rounded,
            title: '保存到相册',
          ),
        ];
      },
    );
    await _videoPlayerController.initialize();
    state.isInitialized.value = true;
  }

  Future<void> nextVideo() async {
    if (state.videoIndex.value < state.videoPathList.length - 1) {
      state.videoIndex.value++;
      await _videoPlayerController.dispose();
      chewieController.dispose();
      initVideo();
    }
  }

  Future<void> previousVideo() async {
    if (state.videoIndex.value > 0) {
      state.videoIndex.value--;
      await _videoPlayerController.dispose();
      chewieController.dispose();
      initVideo();
    }
  }
}
