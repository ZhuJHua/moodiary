import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_utils/moodiary_utils.dart';

/// 音频时长缓存：用 Rust（lofty）只读文件头拿时长，不建播放器实例；结果按路径记忆，
/// 待命卡片据此显示时长。同一路径的并发请求合流。
class _AudioDurationCache {
  static final Map<String, Duration> _cache = {};
  static final Map<String, Future<Duration?>> _inflight = {};

  static Duration? cached(String path) => _cache[path];

  static Future<Duration?> resolve(String path) {
    final hit = _cache[path];
    if (hit != null) return Future.value(hit);
    return _inflight.putIfAbsent(path, () async {
      try {
        final ms = await rust.audioDurationMs(path: path);
        final d = (ms != null && ms > 0)
            ? Duration(milliseconds: ms.toInt())
            : null;
        if (d != null) _cache[path] = d;
        return d;
      } catch (e, s) {
        logger.e('[audio] duration failed path=$path', error: e, stackTrace: s);
        return null;
      } finally {
        _inflight.remove(path);
      }
    });
  }
}

/// 播放进度快照（活动音轨用）。
class AudioProgress {
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool muted;

  const AudioProgress({
    required this.position,
    required this.duration,
    required this.playing,
    required this.muted,
  });

  static const zero = AudioProgress(
    position: Duration.zero,
    duration: Duration.zero,
    playing: false,
    muted: false,
  );
}

/// 单实例音频控制器：全程只持有一个 [AudioPlayer]，同一时刻只播一条；原生解码器在首次
/// 播放时才真正初始化（点了再建）。媒体库整页共享一个实例，从而把「一屏 N 个播放器」降为
/// 一个。Quill 音频嵌入各自持有一个（一篇日记内音频不多）。
class AudioPlaybackController {
  final _player = AudioPlayer();

  /// 当前（或最近）播放的文件路径；null = 空闲。切换即停上一条。
  final ValueNotifier<String?> activePath = ValueNotifier(null);

  /// 活动音轨的进度快照（非活动 tile 不订阅它，故进度 tick 只重建活动那一条）。
  final ValueNotifier<AudioProgress> progress = ValueNotifier(
    AudioProgress.zero,
  );

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<void> _completeSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _muted = false;
  bool _completed = false;

  // seek 抑制：seek 后 ExoPlayer 会瞬时回报 0/旧位置；先按目标显示，待流回报追上目标再跟随，
  // 否则松手后进度条会闪回 0（看起来像从头重播）。设一个兜底定时器防止永久卡住。
  Duration? _pendingSeek;
  Timer? _seekGuard;

  AudioPlaybackController() {
    _posSub = _player.onPositionChanged.listen((d) {
      final pending = _pendingSeek;
      if (pending != null) {
        if ((d - pending).abs() > const Duration(seconds: 1)) return;
        _pendingSeek = null;
      }
      _emit(position: d);
    });
    _durSub = _player.onDurationChanged.listen((d) => _emit(duration: d));
    _stateSub = _player.onPlayerStateChanged.listen(
      (s) => _emit(playing: s == PlayerState.playing),
    );
    _completeSub = _player.onPlayerComplete.listen((_) {
      _completed = true;
      _emit(position: Duration.zero, playing: false);
    });
  }

  void _emit({
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? muted,
  }) {
    _position = position ?? _position;
    _duration = duration ?? _duration;
    _playing = playing ?? _playing;
    _muted = muted ?? _muted;
    progress.value = AudioProgress(
      position: _position,
      duration: _duration,
      playing: _playing,
      muted: _muted,
    );
  }

  Future<void> toggle(String path) async {
    try {
      if (activePath.value == path) {
        if (_playing) {
          await _player.pause();
        } else if (_completed) {
          _completed = false;
          await _player.play(DeviceFileSource(path));
        } else {
          await _player.resume();
        }
      } else {
        // 切换音轨：重置进度并以文件源一步播放（设源+预备+播放，最可靠）。
        activePath.value = path;
        _completed = false;
        _pendingSeek = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _emit();
        await _player.play(DeviceFileSource(path));
      }
    } catch (e, s) {
      logger.e('[audio] play failed', error: e, stackTrace: s);
    }
  }

  Future<void> seek(double fraction) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (fraction * _duration.inMilliseconds).round(),
    );
    _pendingSeek = target;
    _emit(position: target);
    _seekGuard?.cancel();
    _seekGuard = Timer(
      const Duration(milliseconds: 600),
      () => _pendingSeek = null,
    );
    try {
      await _player.seek(target);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    final next = !_muted;
    _emit(muted: next);
    await _player.setVolume(next ? 0 : 1);
  }

  void dispose() {
    _seekGuard?.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _completeSub.cancel();
    _player.dispose();
    activePath.dispose();
    progress.dispose();
  }
}

/// 绑定到 [AudioPlaybackController] 的一条音频卡片：仅当自己是活动音轨时才订阅进度并显示
/// 播放态，否则是待命态（点了才成为活动音轨、才初始化播放器）。
class AudioTile extends StatelessWidget {
  final AudioPlaybackController controller;
  final String path;

  const AudioTile({super.key, required this.controller, required this.path});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.activePath,
      builder: (context, active, _) {
        if (active != path) {
          return _IdleAudioBar(
            path: path,
            onToggle: () => controller.toggle(path),
            onToggleMute: controller.toggleMute,
          );
        }
        return ValueListenableBuilder<AudioProgress>(
          valueListenable: controller.progress,
          builder: (context, p, _) => AudioBar(
            playing: p.playing,
            position: p.position,
            duration: p.duration,
            muted: p.muted,
            onToggle: () => controller.toggle(path),
            onSeek: controller.seek,
            onToggleMute: controller.toggleMute,
          ),
        );
      },
    );
  }
}

/// 单条音频播放条（自持一个 [AudioPlaybackController]）。适合只有一条音频的场景，如 Quill
/// 富文本嵌入。样式与状态复用共享的 [AudioTile] / [AudioBar]。
class AudioPlayerComponent extends StatefulWidget {
  final String path;

  const AudioPlayerComponent({super.key, required this.path});

  @override
  State<AudioPlayerComponent> createState() => _AudioPlayerComponentState();
}

class _AudioPlayerComponentState extends State<AudioPlayerComponent> {
  late final AudioPlaybackController _controller = AudioPlaybackController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AudioTile(controller: _controller, path: widget.path);
  }
}

/// 待命态音频卡片：不建播放器，只经 [_AudioDurationCache]（Rust 读头）拿时长并显示 `0:00 /
/// 时长`，进度条不可拖。点播放键即成为活动音轨。
class _IdleAudioBar extends StatefulWidget {
  final String path;
  final VoidCallback onToggle;
  final VoidCallback onToggleMute;

  const _IdleAudioBar({
    required this.path,
    required this.onToggle,
    required this.onToggleMute,
  });

  @override
  State<_IdleAudioBar> createState() => _IdleAudioBarState();
}

class _IdleAudioBarState extends State<_IdleAudioBar> {
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadDuration();
  }

  void _loadDuration() {
    final cached = _AudioDurationCache.cached(widget.path);
    if (cached != null) {
      _duration = cached;
      return;
    }
    _AudioDurationCache.resolve(widget.path).then((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AudioBar(
      playing: false,
      position: Duration.zero,
      duration: _duration,
      muted: false,
      enabled: false,
      onToggle: widget.onToggle,
      onSeek: (_) {},
      onToggleMute: widget.onToggleMute,
    );
  }
}

/// 音频播放条的纯视觉（样式对齐 TipTap 编辑器内音频节点：圆角描边容器 + 圆形主色播放键 +
/// 细主色进度条 + 时间 + 幽灵静音键）。进度拖拽状态本地维护，松手回调 [onSeek]（0..1）。
class AudioBar extends StatefulWidget {
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool muted;

  /// 进度条是否可拖拽定位。待命卡片显示时长但不可拖（无正在播放的音轨可定位）。
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;
  final VoidCallback onToggleMute;

  const AudioBar({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.muted,
    required this.onToggle,
    required this.onSeek,
    required this.onToggleMute,
    this.enabled = true,
  });

  @override
  State<AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<AudioBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final hasDuration = widget.duration.inMilliseconds > 0;
    final canSeek = widget.enabled && hasDuration;
    final progress = _dragging
        ? _dragValue
        : (hasDuration
              ? (widget.position.inMilliseconds /
                        widget.duration.inMilliseconds)
                    .clamp(0.0, 1.0)
              : 0.0);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.largeBorderRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: widget.onToggle,
              iconSize: 22,
              icon: Icon(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: scheme.primary,
                  inactiveTrackColor: scheme.primary.withValues(alpha: 0.2),
                  thumbColor: scheme.primary,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: progress,
                  onChangeStart: canSeek
                      ? (v) {
                          _dragging = true;
                          setState(() => _dragValue = v);
                        }
                      : null,
                  onChanged: canSeek
                      ? (v) => setState(() => _dragValue = v)
                      : null,
                  onChangeEnd: canSeek
                      ? (v) {
                          setState(() => _dragging = false);
                          widget.onSeek(v);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TimeFormat.mediaPosition(widget.position, widget.duration),
              style: context.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: widget.onToggleMute,
              iconSize: 20,
              color: scheme.onSurfaceVariant,
              icon: Icon(
                widget.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
