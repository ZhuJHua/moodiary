import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/animation.dart';
import 'package:mood_diary/pages/edit/edit_logic.dart';
import 'package:refreshed/refreshed.dart';

import 'audio_player_state.dart';

class AudioPlayerLogic extends GetxController
    with GetSingleTickerProviderStateMixin {
  final AudioPlayerState state = AudioPlayerState();

  final AudioPlayer audioPlayer = AudioPlayer();
  late final AnimationController animationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
  late final EditLogic editLogic = Bind.find<EditLogic>();

  @override
  void onReady() {
    audioPlayer.eventStream.listen((event) {
      //读取时间完成
      if (event.eventType == AudioEventType.duration) {
        state.totalDuration.value = event.duration!;
      }
      //播放完成
      if (event.eventType == AudioEventType.complete) {
        animationController.reset();
        state.currentDuration.value = Duration.zero;
        audioPlayer.stop();
      }
    });

    audioPlayer.onPositionChanged.listen((duration) {
      if (state.handleChange.value == false) {
        state.currentDuration.value = duration;
      }
    });
    super.onReady();
  }

  @override
  void onClose() {
    animationController.dispose();
    audioPlayer.dispose();
    super.onClose();
  }

  //初始化获取时长信息
  Future<void> initAudioPlayer(String value) async {
    await audioPlayer.setSourceDeviceFile(value);
  }

  Future<void> play(String path) async {
    await animationController.forward();
    await audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> pause() async {
    await animationController.reverse();
    await audioPlayer.pause();
  }

  Future<void> to(value) async {
    await audioPlayer.seek(state.currentDuration.value);
    state.handleChange.value = false;
  }

  Future<void> changeValue(value) async {
    state.handleChange.value = true;
    state.currentDuration.value = Duration(
        milliseconds:
            (state.totalDuration.value.inMilliseconds * value).toInt());
  }
}
