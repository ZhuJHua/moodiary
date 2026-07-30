// 亮度 / 音量端口的平台实现。**全仓只有这一个文件** import screen_brightness 与
// volume_controller —— 换插件、加桌面端只动这里，控制器和皮肤都不必知情。
import 'dart:async';
import 'dart:io';

import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import 'video_ambient_controller.dart';

/// 播放页用的一组端口。
Map<VideoAmbientChannel, VideoAmbientChannelPort> defaultVideoAmbientPorts() =>
    {
      VideoAmbientChannel.brightness: AppBrightnessPort(),
      VideoAmbientChannel.volume: SystemVolumePort(),
    };

/// application 级亮度：只改本 app 窗口，不写系统设置，因此**不需要 WRITE_SETTINGS 权限**。
/// 离开播放页要 reset，否则整个 app 会一直停在播放时那个亮度上。
class AppBrightnessPort implements VideoAmbientChannelPort {
  @override
  Future<double?> read() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (_) {
      // 平台不支持（模拟器、部分 ROM）—— 返回 null 让控制器把这条通道判为不可用。
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

/// 系统媒体音量。刻意不用播放器自身的 setVolume：那只是给这一路音轨做衰减，
/// 用户按硬件键静音之后我们的音量条就会说谎。
///
/// 代价是 showSystemUI 挂在插件单例上：写它等于全局关掉系统音量弹窗，release 里必须恢复。
/// 同一时刻只可能有一个播放页（show 那边有 _opening 闸 + 独占路由），所以不做引用计数。
class SystemVolumePort implements VideoAmbientChannelPort {
  SystemVolumePort() {
    // 关掉系统弹窗，音量反馈改由我们自己的 HUD 给 —— 两个一起出现会打架。
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

  /// fetchInitialVolume 必须为 false：补发当前值会在开页那一瞬间弹一次音量 HUD。
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
    // 音量本身**不复位**：用户在视频里调到多少，退出后就是多少（主流播放器都这样）。
    // 下面这一次写入写的是当前值、不改音量，只为把 iOS 那个屏外 MPVolumeView 摘掉 ——
    // 在 iOS 上「不显示系统音量弹窗」正是靠往 key window 里插它实现的，而它只会在下一次
    // showSystemUI=true 的 setVolume 里被移除（见插件 VolumeController.swift:34）；
    // 不摘的话，系统音量弹窗会在离开播放页之后的整个 app 里一直失效。
    //
    // **Android 绝不能跟着做**：那边 showSystemUI 直接翻译成 AudioManager.FLAG_SHOW_UI
    // （VolumeController.kt:17），补这一次同值写入就会在退出播放页的瞬间弹一下系统音量条。
    // Android 侧本来也不需要摘任何东西 —— 那个标志只作用于我们自己的写入。
    if (!Platform.isIOS) return;
    try {
      await VolumeController.instance.setVolume(
        await VolumeController.instance.getVolume(),
      );
    } catch (_) {
      // 平台不支持就算了，标志位本身已经复位。
    }
  }
}
