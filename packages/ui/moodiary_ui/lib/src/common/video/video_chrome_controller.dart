// 控制条显隐。**刻意留在 UI 层**：它是纯呈现策略，对播放行为零影响，进核心会让每次显隐
// 都发一次生命周期通知；而且续命只能靠指针事件（点画面、按按钮、拖进度条），核心拿不到。
// 核心唯一要提供的信息是「当前是否有播放意图」，由 state.isPlayIntent 给出。
import 'dart:async';

import 'package:flutter/foundation.dart';

class VideoChromeController extends ValueNotifier<bool> {
  VideoChromeController() : super(true);

  static const _kHideDelay = Duration(seconds: 3);

  Timer? _timer;

  /// 拖进度条 / 面板开着期间钉住，不许自动隐藏。
  int _pins = 0;

  bool _playIntent = false;

  /// 播放意图变化时驱动计时：开播起表，暂停立刻显示并停表 ——
  /// 没有控制条的暂停画面是个死胡同。
  void syncPlayIntent(bool playing) {
    if (_playIntent == playing) return;
    _playIntent = playing;
    keep();
  }

  /// 任何交互都调它续命。
  void keep() {
    value = true;
    _restart();
  }

  /// 点画面：显着就收起（仅播放中——暂停时收起会没有任何操作入口），藏着就叫回来。
  void toggle() {
    if (value && _playIntent) {
      _timer?.cancel();
      _timer = null;
      value = false;
      return;
    }
    keep();
  }

  VoidCallback pin() {
    _pins += 1;
    keep();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _pins -= 1;
      if (_pins <= 0) _restart();
    };
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!_playIntent || _pins > 0) return;
    _timer = Timer(_kHideDelay, () {
      _timer = null;
      value = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
