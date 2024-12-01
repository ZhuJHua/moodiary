import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import 'audio_player_logic.dart';

class SmallThumbShape extends SfThumbShape {
  @override
  Size getPreferredSize(dynamic themeData) {
    return Size.fromRadius(themeData.thumbRadius - 2); // 自定义更小的尺寸
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required RenderBox? child,
    required dynamic themeData,
    SfRangeValues? currentValues,
    dynamic currentValue,
    required Paint? paint,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required SfThumb? thumb,
  }) {
    // 使用原有逻辑绘制缩小的滑块
    final double radius = getPreferredSize(themeData).width / 2;
    final Paint thumbPaint = Paint()
      ..color = themeData.thumbColor ?? Colors.blue
      ..isAntiAlias = true;

    context.canvas.drawCircle(center, radius, thumbPaint);

    if (child != null) {
      context.paintChild(child, Offset(center.dx - child.size.width / 2, center.dy - child.size.height / 2));
    }
  }
}

class NoOverlayShape extends SfOverlayShape {
  @override
  void paint(PaintingContext context, Offset center,
      {required RenderBox parentBox,
      required dynamic themeData,
      SfRangeValues? currentValues,
      currentValue,
      required Paint? paint,
      required Animation<double> animation,
      required SfThumb? thumb}) {}
}

class AudioPlayerComponent extends StatelessWidget {
  const AudioPlayerComponent({super.key, required this.path});

  final String path;


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
      assignId: true,
      builder: (_) {
        return Card.filled(
          color: colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() {
                        return SfSlider(
                          value: state.totalDuration.value != Duration.zero
                              ? ((state.currentDuration.value.inMilliseconds / state.totalDuration.value.inMilliseconds)
                                  .clamp(0, 1))
                              : 0,
                          onChangeEnd: (value) {
                            logic.to(value);
                          },
                          onChanged: (value) {
                            logic.changeValue(value);
                          },
                          inactiveColor: colorScheme.surfaceContainer,
                          overlayShape: NoOverlayShape(),
                          thumbShape: SmallThumbShape(),
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
                            IconButton.filled(
                              onPressed: () {
                                logic.audioPlayer.state == PlayerState.playing ? logic.pause() : logic.play(path);
                              },
                              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              icon: AnimatedIcon(
                                icon: AnimatedIcons.play_pause,
                                color: colorScheme.onPrimary,
                                progress: logic.animationController,
                              ),
                            ),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
