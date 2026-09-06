import 'dart:async';

import 'package:flutter/foundation.dart';

class VideoChromeController extends ValueNotifier<bool> {
  VideoChromeController() : super(true);

  static const _kHideDelay = Duration(seconds: 3);

  Timer? _timer;

  int _pins = 0;

  bool _playIntent = false;

  void syncPlayIntent(bool playing) {
    if (_playIntent == playing) return;
    _playIntent = playing;
    keep();
  }

  void keep() {
    value = true;
    _restart();
  }

  void toggle() {
    if (value && _playIntent) {
      _timer?.cancel();
      _timer = null;
      value = false;
      return;
    }
    keep();
  }

  VoidCallback pin({bool reveal = true}) {
    _pins += 1;
    if (reveal) {
      keep();
    } else {
      _restart();
    }
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
