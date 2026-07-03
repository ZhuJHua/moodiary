import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 媒体库视频全屏播放页，黑底居中铺放 [VideoPlayerComponent]。
class MediaVideoViewer extends StatelessWidget {
  final String name;

  const MediaVideoViewer({super.key, required this.name});

  static Future<void> show(BuildContext context, {required String name}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => MediaVideoViewer(name: name),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = FileUtil.getRealPath('video', name);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(child: VideoPlayerComponent(videoPath: path, isEdit: true)),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
