// 亮度 / 音量：左右半屏上下滑动的两个通道。
//
// 分层与播放核心一致 —— 这里只有 dart:async + foundation，平台调用全在
// VideoAmbientChannelPort 后面，全仓只有 video_ambient_port_impl.dart 会 import
// screen_brightness / volume_controller。于是「按下取基准 → 跟手 → 抑制回声 →
// 停手后延时收起」这套逻辑能在纯 Dart 单测里跑完。
//
// 两条通道语义不同，别合并成一条：
//   亮度 = application 级（只改本 app 窗口，不需要 WRITE_SETTINGS），离开播放页必须复位；
//   音量 = **系统媒体音量**，不是播放器自身音量 —— 后者在用户按硬件键静音后会让音量条说谎，
//         这也是这个播放器早先干脆不提供音量控制的原因。
//
// 系统媒体音量是分档的（Android 常见 15 档），写 0.43 会落到最近一档、读回来就不是 0.43。
// 所以拖动期间以手指为准并屏蔽端口回声，停手一小段时间后才重新接受外部值。
import 'dart:async';

import 'package:flutter/foundation.dart';

enum VideoAmbientChannel { brightness, volume }

/// 把竖向拖动的落点换算成通道：左三分之一亮度、右三分之一音量，**中间三分之一留给下拉关闭**
/// —— 全占掉的话这个播放器就没有退出手势了（关闭键会跟着 chrome 一起自动隐藏）。
///
/// 这里的「左右」就是用户看到的左右：横拍视频会把整个 app 锁成横屏，widget 坐标系随之旋转，
/// 于是 localPosition.dx 在两种朝向下都已经是视线里的水平方向，不需要再按朝向换算。
VideoAmbientChannel? ambientChannelForX(double dx, double width) {
  if (width <= 0) return null;
  if (dx < width / 3) return .brightness;
  if (dx > width * 2 / 3) return .volume;
  return null;
}

/// 当前该显示的调节量。null 表示 HUD 不该出现。
@immutable
class VideoAmbientLevel {
  const VideoAmbientLevel({required this.channel, required this.value});

  final VideoAmbientChannel channel;

  /// 0..1。
  final double value;

  @override
  bool operator ==(Object other) =>
      other is VideoAmbientLevel &&
      other.channel == channel &&
      other.value == value;

  @override
  int get hashCode => Object.hash(channel, value);
}

/// 一条通道的平台端口。
abstract class VideoAmbientChannelPort {
  /// 读当前值；读不到（平台不支持 / 抛异常）返回 null，此时该通道整体不可用。
  Future<double?> read();

  Future<void> write(double value);

  /// 外部变化（硬件音量键、系统亮度条）。没有就给 [Stream.empty]。
  /// **不要**在订阅时补发当前值 —— 那会在开页瞬间弹一次 HUD。
  Stream<double> get changes;

  /// 收尾：亮度复位、音量恢复系统弹窗。
  Future<void> release();
}

class VideoAmbientController {
  VideoAmbientController({
    required this.ports,
    this.linger = const Duration(milliseconds: 800),
    this.echoWindow = const Duration(milliseconds: 500),
  });

  final Map<VideoAmbientChannel, VideoAmbientChannelPort> ports;

  /// 停手后 HUD 继续停留的时长。
  final Duration linger;

  /// 写入后忽略端口回声的时长（见文件头关于分档的说明）。
  final Duration echoWindow;

  /// 全程（0 → 1）需要划过的屏幕高度比例。太短会失控，太长划不到头。
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

  /// 是否已知这条通道的当前值。UI 可以据此决定要不要把那三分之一让给下拉关闭。
  bool isReady(VideoAmbientChannel channel) => _values.containsKey(channel);

  double? valueOf(VideoAmbientChannel channel) => _values[channel];

  /// 开页就读初值并挂外部监听。**必须在第一次手势之前完成**，否则第一次滑动没有基准点。
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

  // ─────────────────────────── 手势 ───────────────────────────

  /// 手指按下。初值还没读到也接手（那一段位移会被丢掉，读到之后接着走），
  /// 至于「该不该把这一侧让给别的手势」由调用方按 [isReady] 决定。
  void begin(VideoAmbientChannel channel) {
    if (_disposed) return;
    _dragging = channel;
    _dragBase = _values[channel];
    _dragOffset = 0;
    final base = _dragBase;
    if (base != null) _show(channel, base);
  }

  /// [fraction] 为「本次位移 / 全程距离」，向上为正。
  void dragBy(VideoAmbientChannel channel, double fraction) {
    if (_disposed || _dragging != channel) return;
    var base = _dragBase;
    if (base == null) {
      // prime 迟到：把它落地的这一刻当基准，之前的位移作废。
      base = _values[channel];
      if (base == null) return;
      _dragBase = base;
      _dragOffset = fraction;
    } else {
      _dragOffset += fraction;
    }
    // 位移本身也要夹住。否则在顶到 1.0 之后继续上滑会攒下「欠账」，
    // 想调回来得先把这段欠账划完，手感像卡住了。
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

  /// 手指离开（含手势被系统抢走时的 cancel）。
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

  // ─────────────────────────── 写入 ───────────────────────────

  /// 单飞 + 最新值覆盖：跟手时每帧都会来一个新值，逐个 await 会把平台通道排满，
  /// 只保留「最后一个还没写下去的值」。
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
        // 写入期间可能已经 dispose（退出播放页），此时再挂表就没人取消了。
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

  /// 外部改动。音量分档造成的回声在窗口内被丢掉。
  void _onExternal(VideoAmbientChannel channel, double raw) {
    if (_disposed || _dragging == channel) return;
    if (_echoTimers.containsKey(channel)) return;
    final v = raw.clamp(0.0, 1.0);
    if (_values[channel] == v) return;
    _values[channel] = v;
    // 硬件音量键：iOS 上系统弹窗被那个屏外 MPVolumeView 全局压掉了，我们不给反馈就完全没回应；
    // Android 压不掉（那边的 showSystemUI 只作用于我们自己的写入），但条也得跟着动 ——
    // 不然下次起手的基准就是错的。亮度没这个问题（用户在系统控制中心里改，那儿本来就有反馈）。
    if (channel != .volume) return;
    _show(channel, v);
    _armHide();
  }

  // ─────────────────────────── HUD ───────────────────────────

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

  /// 严格顺序：置闸 → 停表 → 退订 → 让端口收尾（亮度复位、音量恢复系统弹窗）→ dispose notifier。
  /// 端口的 release 不 await —— 收尾挂住不该拖着页面退出。
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
