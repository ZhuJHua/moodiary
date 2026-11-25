import 'dart:async';
import 'dart:io';

import 'package:mui/mui.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

Map<VideoAmbientChannel, VideoAmbientChannelPort> defaultVideoAmbientPorts() =>
    {.brightness: AppBrightnessPort(), .volume: SystemVolumePort()};

class AppBrightnessPort implements VideoAmbientChannelPort {
  @override
  Future<double?> read() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(double value) =>
      ScreenBrightness.instance.setApplicationScreenBrightness(value);

  @override
  Stream<double> get changes =>
      ScreenBrightness.instance.onApplicationScreenBrightnessChanged;

  @override
  Future<void> release() =>
      ScreenBrightness.instance.resetApplicationScreenBrightness();
}

class SystemVolumePort implements VideoAmbientChannelPort {
  SystemVolumePort() {
    VolumeController.instance.showSystemUI = false;
  }

  StreamController<double>? _ctl;

  @override
  Future<double?> read() async {
    try {
      return await VolumeController.instance.getVolume();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(double value) =>
      VolumeController.instance.setVolume(value);

  @override
  Stream<double> get changes {
    final ctl = _ctl ??= StreamController<double>.broadcast(
      onListen: () => VolumeController.instance.addListener(
        (v) => _ctl?.add(v),
        fetchInitialVolume: false,
      ),
      onCancel: VolumeController.instance.removeListener,
    );
    return ctl.stream;
  }

  @override
  Future<void> release() async {
    VolumeController.instance.removeListener();
    await _ctl?.close();
    _ctl = null;
    VolumeController.instance.showSystemUI = true;
    // iOS 靠一次同值写入摘掉隐藏的 MPVolumeView（否则系统音量弹窗一直失效）；Android 同样写入会弹出音量条
    if (!Platform.isIOS) return;
    try {
      await VolumeController.instance.setVolume(
        await VolumeController.instance.getVolume(),
      );
    } catch (_) {}
  }
}
