import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/edit/edit_logic.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'record_sheet_state.dart';

class RecordSheetLogic extends GetxController with GetTickerProviderStateMixin {
  final RecordSheetState state = RecordSheetState();

  late final AudioRecorder audioRecorder = AudioRecorder();

  //按钮动画控制器
  late AnimationController animationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0, upperBound: 1.0);

  late final editLogic = Bind.find<EditLogic>();

  late double baseline = .0;

  @override
  void onReady() {
    // TODO: implement onReady

    super.onReady();
  }

  @override
  void onClose() async {
    // TODO: implement onClose
    if (state.isStop == false) {
      await audioRecorder.cancel();
    }
    await audioRecorder.dispose();
    animationController.dispose();
    super.onClose();
  }

  void initMaxWidth(value) {
    state.maxWidth = value;
  }

  Future<void> startRecorder() async {
    if (await Utils().permissionUtil.checkPermission(Permission.microphone) &&
        await Utils().permissionUtil.checkPermission(Permission.bluetoothConnect)) {
      await animationController.forward();
      state.isRecording.value = true;
      state.isStarted.value = true;
      state.height.value = 140.0;
      state.fileName = 'audio-${const Uuid().v7()}.m4a';

      ///开始录制
      ///暂时保存在缓存目录中
      await audioRecorder.start(
          const RecordConfig(androidConfig: AndroidRecordConfig(muteAudio: true, useLegacy: true)),
          path: Utils().fileUtil.getCachePath(state.fileName));
      //启动监听
      listenAmplitude();
    }
  }

  void listenAmplitude() {
    final amplitudeStream = audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 40));
    amplitudeStream.listen((amplitude) {
      state.durationTime.value += const Duration(milliseconds: 40);
      if (amplitude.current.isInfinite) {
        maxLengthAdd(.0);
      } else if (amplitude.current != amplitude.max) {
        maxLengthAdd(normalizeAmplitude(amplitude.current));
      }
    });
  }

  double normalizeAmplitude(double amplitude) {
    baseline = min(baseline, amplitude);
    return (amplitude + baseline.abs()) / baseline.abs();
  }

  void maxLengthAdd(value) {
    if (state.amplitudes.length > state.maxWidth ~/ (state.barWidth + state.spaceWidth)) {
      state.amplitudes.removeAt(0);
    }
    state.amplitudes.add(value);
  }

  Future<void> stopRecorder() async {
    state.isStop = true;
    await audioRecorder.stop();
    animationController.reset();
    editLogic.setAudioName(state.fileName);
    Get.backLegacy();
  }

  Future<void> pauseRecorder() async {
    state.isRecording.value = false;
    await audioRecorder.pause();
    await animationController.reverse();
  }

  Future<void> resumeRecorder() async {
    await animationController.forward();
    state.isRecording.value = true;
    await audioRecorder.resume();
  }

  Future<void> cancelRecorder() async {
    state.amplitudes.value = <double>[];
    state.durationTime.value = const Duration();
    animationController.reset();
    state.isStarted.value = false;
    state.isRecording.value = false;
    state.height.value = 0;
    await audioRecorder.cancel();
  }
}
