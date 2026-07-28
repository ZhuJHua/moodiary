import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_ui/src/basic/loading.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerComponent extends StatefulWidget {
  final String videoPath;

  final bool isEdit;

  const VideoPlayerComponent({
    super.key,
    required this.videoPath,
    required this.isEdit,
  });

  @override
  State<VideoPlayerComponent> createState() => _VideoPlayerComponentState();
}

class _VideoPlayerComponentState extends State<VideoPlayerComponent> {
  late final videoPlayerController = VideoPlayerController.file(
    File(widget.videoPath),
  );
  late final chewieController = ChewieController(
    videoPlayerController: videoPlayerController,
    hideControlsTimer: Durations.extralong4,
  );

  Completer<void>? _initCompleter;

  bool isInitialized = false;

  @override
  void initState() {
    _initCompleter = Completer<void>();
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!(_initCompleter?.isCompleted ?? true)) {
        await videoPlayerController.initialize();
        setState(() {
          isInitialized = true;
        });
        _initCompleter?.complete();
      }
    });
    super.initState();
  }

  void cancelInitialization() {
    if (!(_initCompleter?.isCompleted ?? true)) {
      _initCompleter?.complete();
    }
  }

  @override
  void dispose() {
    cancelInitialization();
    videoPlayerController.dispose();
    chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isInitialized
            ? Stack(
                children: [
                  if (!widget.isEdit)
                    Positioned.fill(
                      child: Image.file(
                        File(
                          AppFiles.getRealPath(
                            'thumbnail',
                            basename(widget.videoPath),
                          ),
                        ),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(color: Colors.black38),
                  ),
                  Chewie(controller: chewieController),
                ],
              )
            : const MoodiaryLoading(),
      ),
    );
  }
}
