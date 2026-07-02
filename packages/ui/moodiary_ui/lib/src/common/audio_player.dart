import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';

class AudioPlayerComponent extends StatefulWidget {
  final String path;

  const AudioPlayerComponent({super.key, required this.path});

  @override
  State<AudioPlayerComponent> createState() => _AudioPlayerComponentState();
}

class _AudioPlayerComponentState extends State<AudioPlayerComponent> {
  final _player = AudioPlayer();
  late String _currentPath;

  Duration _total = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  // 用户按住滑块时禁用流式更新，避免拖拽指与流值打架。
  bool _dragging = false;
  double _dragValue = 0.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _bindStreams();
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant AudioPlayerComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _currentPath = widget.path;
      _loadSource();
    }
  }

  void _bindStreams() {
    _posSub = _player.onPositionChanged.listen((d) {
      if (!mounted || _dragging) return;
      setState(() => _position = d);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _total = d);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  Future<void> _loadSource() async {
    try {
      await _player.setSourceDeviceFile(_currentPath);
    } catch (_) {
      // 加载失败保留默认状态；UI 会显示 0:00 / 0:00 的禁用条。
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final hasDuration = _total.inMilliseconds > 0;
    final progress = _dragging
        ? _dragValue
        : (hasDuration
              ? (_position.inMilliseconds / _total.inMilliseconds).clamp(
                  0.0,
                  1.0,
                )
              : 0.0);
    return Card.filled(
      color: scheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: hasDuration ? _toggle : null,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: progress,
                  onChangeStart: hasDuration
                      ? (v) {
                          _dragging = true;
                          _dragValue = v;
                        }
                      : null,
                  onChanged: hasDuration
                      ? (v) {
                          setState(() => _dragValue = v);
                        }
                      : null,
                  onChangeEnd: hasDuration
                      ? (v) async {
                          _dragging = false;
                          final ms = (v * _total.inMilliseconds).round();
                          await _player.seek(Duration(milliseconds: ms));
                          if (mounted) {
                            setState(() => _position = Duration(milliseconds: ms));
                          }
                        }
                      : null,
                ),
              ),
            ),
            Text(
              '${_fmt(_position)} / ${_fmt(_total)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
