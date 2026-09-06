import 'dart:async';

import 'package:flutter/foundation.dart';

enum VideoAmbientChannel { brightness, volume }

VideoAmbientChannel? ambientChannelForX(double dx, double width) {
  if (width <= 0) return null;
  if (dx < width / 3) return .brightness;
  if (dx > width * 2 / 3) return .volume;
  return null;
}

@immutable
class VideoAmbientLevel {
  const VideoAmbientLevel({required this.channel, required this.value});

  final VideoAmbientChannel channel;

  final double value;

  @override
  bool operator ==(Object other) =>
      other is VideoAmbientLevel &&
      other.channel == channel &&
      other.value == value;

  @override
  int get hashCode => Object.hash(channel, value);
}

abstract class VideoAmbientChannelPort {
  Future<double?> read();

  Future<void> write(double value);

  Stream<double> get changes;

  Future<void> release();
}

class VideoAmbientController {
  VideoAmbientController({
    required this.ports,
    this.linger = const Duration(milliseconds: 800),
    this.echoWindow = const Duration(milliseconds: 500),
  });

  final Map<VideoAmbientChannel, VideoAmbientChannelPort> ports;

  final Duration linger;

  final Duration echoWindow;

  static const travelFraction = 0.62;

  final active = ValueNotifier<VideoAmbientLevel?>(null);

  final _values = <VideoAmbientChannel, double>{};
  final _subs = <VideoAmbientChannel, StreamSubscription<double>>{};
  final _echoTimers = <VideoAmbientChannel, Timer>{};
  final _pending = <VideoAmbientChannel, double>{};
  final _inFlight = <VideoAmbientChannel>{};
  final _warned = <VideoAmbientChannel>{};

  Timer? _hideTimer;
  VideoAmbientChannel? _dragging;
  double? _dragBase;
  double _dragOffset = 0;
  bool _disposed = false;

  bool isReady(VideoAmbientChannel channel) => _values.containsKey(channel);

  double? valueOf(VideoAmbientChannel channel) => _values[channel];

  void prime() {
    if (_disposed) return;
    for (final entry in ports.entries) {
      final channel = entry.key;
      final port = entry.value;
      unawaited(() async {
        try {
          final v = await port.read();
          if (_disposed || v == null) return;
          _values[channel] = v.clamp(0.0, 1.0);
        } catch (e) {
          _warnOnce(channel, 'read', e);
        }
      }());
      _subs[channel] = port.changes.listen(
        (v) => _onExternal(channel, v),
        onError: (Object e) => _warnOnce(channel, 'changes', e),
      );
    }
  }

  void begin(VideoAmbientChannel channel) {
    if (_disposed) return;
    _dragging = channel;
    _dragBase = _values[channel];
    _dragOffset = 0;
    final base = _dragBase;
    if (base != null) _show(channel, base);
  }

  void dragBy(VideoAmbientChannel channel, double fraction) {
    if (_disposed || _dragging != channel) return;
    var base = _dragBase;
    if (base == null) {
      base = _values[channel];
      if (base == null) return;
      _dragBase = base;
      _dragOffset = fraction;
    } else {
      _dragOffset += fraction;
    }
    _dragOffset = _dragOffset.clamp(-base, 1 - base);
    final next = (base + _dragOffset).clamp(0.0, 1.0);
    if (_values[channel] == next) {
      _show(channel, next);
      return;
    }
    _values[channel] = next;
    _show(channel, next);
    _write(channel, next);
  }

  void end() {
    if (_disposed) return;
    final channel = _dragging;
    _dragging = null;
    _dragBase = null;
    _dragOffset = 0;
    if (channel == null) return;
    final v = _values[channel];
    if (v == null) {
      _clear();
      return;
    }
    _show(channel, v);
    _armHide();
  }

  void _write(VideoAmbientChannel channel, double value) {
    _pending[channel] = value;
    _armEcho(channel);
    if (_inFlight.contains(channel)) return;
    unawaited(_drain(channel));
  }

  Future<void> _drain(VideoAmbientChannel channel) async {
    _inFlight.add(channel);
    try {
      while (!_disposed) {
        final v = _pending.remove(channel);
        if (v == null) break;
        try {
          await ports[channel]?.write(v);
        } catch (e) {
          _warnOnce(channel, 'write', e);
        }
        if (_disposed) break;
        _armEcho(channel);
      }
    } finally {
      _inFlight.remove(channel);
    }
  }

  void _armEcho(VideoAmbientChannel channel) {
    _echoTimers[channel]?.cancel();
    _echoTimers[channel] = Timer(echoWindow, () => _echoTimers.remove(channel));
  }

  void _onExternal(VideoAmbientChannel channel, double raw) {
    if (_disposed || _dragging == channel) return;
    if (_echoTimers.containsKey(channel)) return;
    final v = raw.clamp(0.0, 1.0);
    if (_values[channel] == v) return;
    _values[channel] = v;
    if (channel != .volume) return;
    _show(channel, v);
    _armHide();
  }

  void _show(VideoAmbientChannel channel, double value) {
    _hideTimer?.cancel();
    _hideTimer = null;
    active.value = VideoAmbientLevel(channel: channel, value: value);
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(linger, () {
      _hideTimer = null;
      if (!_disposed) active.value = null;
    });
  }

  void _clear() {
    _hideTimer?.cancel();
    _hideTimer = null;
    active.value = null;
  }

  void _warnOnce(VideoAmbientChannel channel, String op, Object error) {
    if (!_warned.add(channel)) return;
    debugPrint('video ambient ${channel.name} $op failed: $error');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _hideTimer?.cancel();
    _hideTimer = null;
    for (final t in _echoTimers.values) {
      t.cancel();
    }
    _echoTimers.clear();
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
    for (final port in ports.values) {
      unawaited(
        port.release().catchError((Object e) {
          debugPrint('video ambient release failed: $e');
        }),
      );
    }
    active.dispose();
  }
}
