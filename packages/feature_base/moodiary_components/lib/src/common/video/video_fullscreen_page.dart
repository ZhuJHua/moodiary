import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show DeviceOrientation, HapticFeedback;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'video_ambient_port_impl.dart';
import 'video_player_port_impl.dart';

typedef VideoSurfaceBuilder = Widget Function(VideoPlaybackPort port);

// 0.6 = 一屏滑动覆盖时长的比例；1000/6 = 单位像素毫秒数封顶（长片一屏≈67秒）
double scrubMillisPerPixel(Duration duration, double width) {
  if (width <= 0) return 0;
  return math.min(0.6 * duration.inMilliseconds / width, 1000 / 6);
}

Widget defaultVideoSurfaceBuilder(VideoPlaybackPort port) =>
    port is VideoPlayerPluginPort
    ? port.buildSurface()
    : const SizedBox.shrink();

class MVideoPlayerPage extends StatefulWidget {
  const MVideoPlayerPage({
    super.key,
    required this.videoPath,
    this.coverPath,
    this.initialAspect,
    this.startAt = .zero,
    this.onExitAt,
    this.surfaceBuilder = defaultVideoSurfaceBuilder,
    this.portFactory = videoPlayerPortFactory,
    this.ambientPorts,
  });

  final String videoPath;

  final String? coverPath;

  final double? initialAspect;

  final Duration startAt;

  final ValueChanged<Duration>? onExitAt;

  final VideoSurfaceBuilder surfaceBuilder;

  final VideoPlaybackPortFactory portFactory;

  final Map<VideoAmbientChannel, VideoAmbientChannelPort>? ambientPorts;

  static Future<void> show(
    BuildContext context, {
    required String videoPath,
    String? coverPath,
    double? initialAspect,
    Duration startAt = .zero,
    ValueChanged<Duration>? onExitAt,
    VideoPlaybackPortFactory portFactory = videoPlayerPortFactory,
    Map<VideoAmbientChannel, VideoAmbientChannelPort>? ambientPorts,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: Durations.medium2,
        reverseTransitionDuration: Durations.medium1,
        pageBuilder: (_, _, _) => MVideoPlayerPage(
          videoPath: videoPath,
          coverPath: coverPath,
          initialAspect: initialAspect,
          startAt: startAt,
          onExitAt: onExitAt,
          portFactory: portFactory,
          ambientPorts: ambientPorts,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static bool _opening = false;

  static Future<void> showByName(
    BuildContext context, {
    required String name,
    Duration startAt = .zero,
    ValueChanged<Duration>? onExitAt,
    VideoPlaybackPortFactory portFactory = videoPlayerPortFactory,
    Map<VideoAmbientChannel, VideoAmbientChannelPort>? ambientPorts,
  }) async {
    if (_opening) return;
    _opening = true;
    final double? aspect;
    final String videoPath;
    final String? coverPath;
    try {
      videoPath = AppFiles.getRealPath('video', name);
      coverPath = _coverPathOf(name);
      aspect = await _coverAspect(coverPath);
    } finally {
      _opening = false;
    }
    if (!context.mounted) return;
    return show(
      context,
      videoPath: videoPath,
      coverPath: coverPath,
      initialAspect: aspect,
      startAt: startAt,
      onExitAt: onExitAt,
      portFactory: portFactory,
      ambientPorts: ambientPorts,
    );
  }

  // getRealPath 对文件名做 substring(6, 42)，长度不对会同步抛 RangeError
  static String? _coverPathOf(String name) {
    try {
      return AppFiles.getRealPath('thumbnail', name);
    } catch (_) {
      return null;
    }
  }

  static Future<double?> _coverAspect(String? coverPath) async {
    if (coverPath == null || !File(coverPath).existsSync()) return null;
    try {
      return await ImageSizeManager().getAspectRatioAsync(coverPath);
    } catch (_) {
      return null;
    }
  }

  @override
  State<MVideoPlayerPage> createState() => _MVideoPlayerPageState();
}

class _MVideoPlayerPageState extends State<MVideoPlayerPage>
    with WidgetsBindingObserver {
  late final MVideoPlaybackController _player;
  final _chrome = VideoChromeController();
  late final _ambient = VideoAmbientController(
    ports: widget.ambientPorts ?? defaultVideoAmbientPorts(),
  );

  OrientationOverrideRelease? _releaseOrientation;
  List<DeviceOrientation>? _lockedTo;

  ImmersiveOverrideRelease? _releaseImmersive;

  bool _entryDone = false;
  List<DeviceOrientation>? _pendingLock;

  bool _rotationInFlight = false;

  bool _exiting = false;
  bool _exitReported = false;
  Completer<void>? _orientationWaiter;
  List<DeviceOrientation>? _waitFor;

  final _dragY = ValueNotifier<double>(0);

  final _hud = ValueNotifier<_ScrubHud?>(null);
  VoidCallback? _unpinChrome;

  final _boost = ValueNotifier<bool>(false);
  double? _speedBeforeBoost;

  static const _kDismissThreshold = 120.0;
  static const _kBoostSpeed = 2.0;

  static const _kRotateTimeout = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _player = MVideoPlaybackController(
      source: .file(widget.videoPath),
      portFactory: widget.portFactory,
      initialAspect: widget.initialAspect,
      autoPlay: false,
    );
    _ambient.prime();
    _ambient.active.addListener(_onAmbientChanged);
    WidgetsBinding.instance.addObserver(this);
    _player.state.addListener(_onStateChanged);
    _player.geometry.addListener(_applyOrientation);
    _player.initialize().then((_) {
      if (mounted && widget.startAt > Duration.zero) {
        _player.seekTo(widget.startAt);
      }
    });
  }

  bool _routeHooked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeHooked) return;
    _routeHooked = true;
    final anim = ModalRoute.of(context)?.animation;
    if (anim == null || anim.status == .completed) {
      _openEntryGate();
      return;
    }
    void onStatus(AnimationStatus s) {
      if (s != .completed) return;
      anim.removeStatusListener(onStatus);
      _openEntryGate();
    }

    anim.addStatusListener(onStatus);
  }

  void _openEntryGate() {
    if (!mounted || _entryDone) return;
    _entryDone = true;
    final pending = _pendingLock ?? _orientationsForCurrentAspect();
    _pendingLock = null;
    if (pending == null) {
      _onStageReady();
      return;
    }
    _lockOrientation(pending);
  }

  bool _stageReady = false;

  void _onStageReady() {
    if (!mounted || _exiting || _stageReady) return;
    _stageReady = true;
    _releaseImmersive ??= enterImmersiveTemporarily();
    _player.play();
    _chrome.keep();
  }

  void _onStateChanged() {
    final state = _player.state.value;
    _chrome.syncPlayIntent(state.isPlayIntent);
    if (!state.isPlayIntent) _endBoost();
  }

  void _onAmbientChanged() {
    if (_ambient.active.value != null) _hideHud();
  }

  List<DeviceOrientation>? _orientationsForCurrentAspect() {
    final aspect = _player.geometry.value.naturalAspect;
    return aspect == null ? null : fullscreenOrientationsFor(aspect);
  }

  void _applyOrientation() {
    if (_releaseOrientation != null || _exiting) return;
    final want = _orientationsForCurrentAspect();
    if (want == null) return;
    if (!_entryDone) {
      _pendingLock = want;
      return;
    }
    _lockOrientation(want);
  }

  void _lockOrientation(List<DeviceOrientation> want) {
    if (_releaseOrientation != null) return;
    if (currentOrientationPolicy() != .portraitOnly) {
      _onStageReady();
      return;
    }
    if (_isCurrentOrientation(want)) {
      _lockedTo = want;
      _releaseOrientation = lockOrientationsTemporarily(want);
      _onStageReady();
      return;
    }
    _lockedTo = want;
    _rotationInFlight = true;
    _releaseOrientation = lockOrientationsTemporarily(want);
    _awaitOrientation(want).then((_) {
      if (!mounted) return;
      _rotationInFlight = false;
      if (_exitRequested) {
        _beginExit();
        return;
      }
      _onStageReady();
    });
  }

  bool _isCurrentOrientation(List<DeviceOrientation> want) {
    final size = View.of(context).physicalSize;
    final landscape = size.width > size.height;
    return want.contains(DeviceOrientation.landscapeLeft) == landscape;
  }

  Future<void> _awaitOrientation(List<DeviceOrientation> want) async {
    if (_isCurrentOrientation(want)) return;
    final waiter = Completer<void>();
    _orientationWaiter = waiter;
    _waitFor = want;
    await Future.any([waiter.future, Future<void>.delayed(_kRotateTimeout)]);
    _orientationWaiter = null;
    _waitFor = null;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void didChangeMetrics() {
    final want = _waitFor;
    final w = _orientationWaiter;
    if (want == null || w == null || w.isCompleted) return;
    if (_isCurrentOrientation(want)) w.complete();
  }

  @override
  void dispose() {
    _reportExit();
    WidgetsBinding.instance.removeObserver(this);
    _ambient.active.removeListener(_onAmbientChanged);
    _player.state.removeListener(_onStateChanged);
    _player.geometry.removeListener(_applyOrientation);
    _unpinChrome?.call();
    _hud.dispose();
    _boost.dispose();
    _dragY.dispose();
    _releaseOrientation?.call();
    _releaseOrientation = null;
    _releaseImmersive?.call();
    _releaseImmersive = null;
    _ambient.dispose();
    _chrome.dispose();
    _player.dispose();
    super.dispose();
  }

  void _showHud(Duration position, {Duration? delta}) {
    _hud.value = _ScrubHud(
      position: position,
      duration: _player.progress.value.duration,
      delta: delta,
    );
  }

  void _hideHud() => _hud.value = null;

  bool _exitRequested = false;

  void _reportExit() {
    if (_exitReported) return;
    _exitReported = true;
    widget.onExitAt?.call(_player.progress.value.position);
  }

  void _close() => _requestExit();

  void _requestExit() {
    if (_exiting) return;
    _exitRequested = true;
    if (_rotationInFlight) return;
    _beginExit();
  }

  Future<void> _beginExit() async {
    if (_exiting) return;
    _exiting = true;
    _endBoost();
    _player.pause();
    _hideHud();
    _dragY.value = 0;
    setState(() {});
    _reportExit();

    final restored = _releaseOrientation?.call() ?? false;
    _releaseOrientation = null;
    if (restored && _lockedTo != null) {
      await _awaitOrientation(const [.portraitUp]);
    }
    _releaseImmersive?.call();
    _releaseImmersive = null;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onTapUp(TapUpDetails d) => _chrome.toggle();

  void _onDoubleTap() {
    final state = _player.state.value;
    if (!state.acceptsCommands) return;
    if (state is VideoCompleted) {
      _player.replay();
      return;
    }
    _player.togglePlay();
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final state = _player.state.value;
    if (!state.isPlayIntent || !state.acceptsCommands) return;
    if (_boost.value) return;
    _speedBeforeBoost = _player.settings.value.speed;
    _boost.value = true;
    _player.setSpeed(_kBoostSpeed);
    HapticFeedback.lightImpact();
  }

  void _endBoost() {
    if (!_boost.value) return;
    _boost.value = false;
    _player.setSpeed(_speedBeforeBoost ?? 1.0);
    _speedBeforeBoost = null;
  }

  bool _inScrubZone(Offset local) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final w = MediaQuery.sizeOf(context).width;
    final left = insets.left > 0 ? insets.left : 24.0;
    final right = insets.right > 0 ? insets.right : 24.0;
    return local.dx > left && local.dx < w - right;
  }

  Duration? _scrubBase;

  Duration _scrubOrigin = .zero;

  void _onHorizontalStart(DragStartDetails d) {
    if (!_inScrubZone(d.localPosition)) return;
    final p = _player.progress.value;
    if (!p.canSeek) return;
    _scrubBase = p.position;
    _scrubOrigin = p.position;
    _unpinChrome = _chrome.pin(reveal: false);
    _player.beginScrub(p.position);
  }

  void _onHorizontalUpdate(DragUpdateDetails d) {
    final base = _scrubBase;
    if (base == null) return;
    final total = _player.progress.value.duration;
    if (total <= Duration.zero) return;
    final w = MediaQuery.sizeOf(context).width;
    final deltaMs = (d.primaryDelta ?? 0) * scrubMillisPerPixel(total, w);
    final next = base + Duration(milliseconds: deltaMs.round());
    _scrubBase = next;
    _player.updateScrub(next);
    final now = _player.progress.value.position;
    _showHud(now, delta: now - _scrubOrigin);
  }

  void _onHorizontalEnd(DragEndDetails d) {
    final base = _scrubBase;
    _scrubBase = null;
    _unpinChrome?.call();
    _unpinChrome = null;
    if (base == null) return;
    _player.endScrub(_player.progress.value.position);
    _hideHud();
  }

  void _onHorizontalCancel() {
    if (_scrubBase == null) return;
    _scrubBase = null;
    _unpinChrome?.call();
    _unpinChrome = null;
    _player.cancelScrub();
    _hideHud();
  }

  VideoAmbientChannel? _ambientChannel;

  void _onVerticalStart(DragStartDetails d) {
    if (_scrubBase != null) return;
    final channel = ambientChannelForX(
      d.localPosition.dx,
      MediaQuery.sizeOf(context).width,
    );
    if (channel == null || !_ambient.isReady(channel)) return;
    _ambientChannel = channel;
    _ambient.begin(channel);
  }

  void _onVerticalUpdate(DragUpdateDetails d) {
    if (_scrubBase != null) return;
    final channel = _ambientChannel;
    if (channel != null) {
      final travel =
          MediaQuery.sizeOf(context).height *
          VideoAmbientController.travelFraction;
      if (travel <= 0) return;
      _ambient.dragBy(channel, -(d.primaryDelta ?? 0) / travel);
      return;
    }
    _dragY.value = (_dragY.value + (d.primaryDelta ?? 0)).clamp(0.0, 400.0);
  }

  void _onVerticalEnd(DragEndDetails d) {
    if (_endAmbientDrag()) return;
    if (_dragY.value > _kDismissThreshold || (d.primaryVelocity ?? 0) > 700) {
      _requestExit();
      return;
    }
    _dragY.value = 0;
  }

  bool _endAmbientDrag() {
    if (_ambientChannel == null) return false;
    _ambientChannel = null;
    _ambient.end();
    return true;
  }

  void _onVerticalCancel() {
    if (_endAmbientDrag()) return;
    _dragY.value = 0;
  }

  Widget _buildSurface() {
    return ValueListenableBuilder<VideoGeometry>(
      valueListenable: _player.geometry,
      builder: (context, geo, _) {
        final port = _player.port;
        final aspect = geo.naturalAspect;
        final surface = port == null
            ? const SizedBox.shrink()
            : KeyedSubtree(
                key: ValueKey(geo.generation),
                child: widget.surfaceBuilder(port),
              );
        return Center(
          child: aspect == null
              ? surface
              : AspectRatio(aspectRatio: aspect, child: surface),
        );
      },
    );
  }

  Widget _buildPoster() {
    final cover = widget.coverPath;
    if (cover == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _player.coverVisible,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();
        return ValueListenableBuilder<VideoGeometry>(
          valueListenable: _player.geometry,
          builder: (context, geo, _) {
            final aspect = geo.naturalAspect;
            final image = Image.file(
              File(cover),
              fit: .contain,
              filterQuality: .low,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
            return Center(
              child: aspect == null
                  ? image
                  : AspectRatio(aspectRatio: aspect, child: image),
            );
          },
        );
      },
    );
  }

  Widget _buildChrome() {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: _chrome,
      builder: (context, visible0, _) {
        final visible = visible0 && !_exiting;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Durations.short3,
            child: Stack(
              children: [
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 8,
                  child: _RoundIcon(
                    icon: LucideIcons.x,
                    tooltip: l10n.common.close,
                    onTap: _close,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomBar(l10n),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(Translations l10n) {
    final inset = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final barHeight = size.width > size.height ? 78.0 : 104.0;
    return Container(
      height: barHeight + inset.bottom,
      padding: .only(
        left: 8 + inset.left,
        right: 12 + inset.right,
        bottom: inset.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: .bottomCenter,
          end: .topCenter,
          stops: [0, 0.26, 0.52, 0.76, 1],
          colors: [
            Color(0x94000000),
            Color(0x66000000),
            Color(0x33000000),
            Color(0x12000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: Row(
        children: [
          ValueListenableBuilder<VideoPlaybackState>(
            valueListenable: _player.state,
            builder: (context, state, _) {
              final completed = state is VideoCompleted;
              return _RoundIcon(
                icon: completed
                    ? LucideIcons.rotateCcw
                    : (state.isPlayIntent
                          ? LucideIcons.pause
                          : LucideIcons.play),
                tooltip: completed
                    ? l10n.ui.videoPlayerReplay
                    : (state.isPlayIntent ? l10n.ui.pause : l10n.ui.play),
                filled: false,
                onTap: () {
                  _chrome.keep();
                  if (completed) {
                    _player.replay();
                  } else {
                    _player.togglePlay();
                  }
                },
              );
            },
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildScrubber(l10n)),
        ],
      ),
    );
  }

  Widget _buildScrubber(Translations l10n) {
    return Row(
      children: [
        Expanded(
          child: _ScrubBar(
            progress: _player.progress,
            semanticLabel: l10n.ui.playbackProgress,
            onBegin: (at) {
              _unpinChrome?.call();
              _unpinChrome = _chrome.pin();
              _player.beginScrub(at);
            },
            onUpdate: _player.updateScrub,
            onEnd: (at) {
              _unpinChrome?.call();
              _unpinChrome = null;
              _player.endScrub(at);
            },
            onNudge: (delta) {
              _chrome.keep();
              _player.skip(delta);
            },
          ),
        ),
        const SizedBox(width: 10),
        _TimeCode(progress: _player.progress),
      ],
    );
  }

  VideoAmbientLevel? _lastAmbient;

  Widget _buildAmbientHud() {
    return ValueListenableBuilder<VideoAmbientLevel?>(
      valueListenable: _ambient.active,
      builder: (context, level, _) {
        if (level != null) _lastAmbient = level;
        final shown = _lastAmbient;
        final visible = level != null && !_exiting;
        if (shown == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: visible ? Durations.short2 : Durations.medium1,
            child: _AmbientBar(level: shown),
          ),
        );
      },
    );
  }

  Widget _buildStateLayer() {
    final l10n = context.l10n;
    if (_exiting) return const SizedBox.shrink();
    return ValueListenableBuilder<VideoPlaybackState>(
      valueListenable: _player.state,
      builder: (context, state, _) => switch (state) {
        VideoError(:final canRetry) => Center(
          child: Column(
            mainAxisSize: .min,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                color: Colors.white70,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.ui.videoPlayerLoadFailed,
                style: context.theme.typography.bodySmall.onSurface.copyWith(
                  color: Colors.white70,
                ),
              ),
              if (canRetry) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _player.retry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: Text(l10n.common.retry),
                ),
              ],
            ],
          ),
        ),
        _ when state.isBusy => const Center(
          child: MLoading(color: Colors.white),
        ),
        VideoCompleted() || VideoReady() => Center(
          child: _RoundIcon(
            icon: state is VideoCompleted
                ? LucideIcons.rotateCcw
                : LucideIcons.play,
            tooltip: state is VideoCompleted
                ? l10n.ui.videoPlayerReplay
                : l10n.ui.play,
            big: true,
            onTap: () {
              _chrome.keep();
              if (state is VideoCompleted) {
                _player.replay();
              } else {
                _player.play();
              }
            },
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<double>(
        valueListenable: _dragY,
        builder: (context, dragY, child) => Opacity(
          opacity: (1 - dragY / 400).clamp(0.4, 1.0),
          child: Transform.translate(offset: Offset(0, dragY), child: child),
        ),
        child: Stack(
          fit: .expand,
          children: [
            _buildSurface(),
            _buildPoster(),
            GestureDetector(
              behavior: .opaque,
              onTapUp: _onTapUp,
              onDoubleTap: _onDoubleTap,
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: (_) => _endBoost(),
              onLongPressCancel: _endBoost,
              onHorizontalDragStart: _onHorizontalStart,
              onHorizontalDragUpdate: _onHorizontalUpdate,
              onHorizontalDragEnd: _onHorizontalEnd,
              onHorizontalDragCancel: _onHorizontalCancel,
              onVerticalDragStart: _onVerticalStart,
              onVerticalDragUpdate: _onVerticalUpdate,
              onVerticalDragEnd: _onVerticalEnd,
              onVerticalDragCancel: _onVerticalCancel,
            ),
            _buildStateLayer(),
            _buildChrome(),
            _buildScrubRail(),
            _buildAmbientHud(),
            _buildScrubHud(),
            _buildBoostBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubHud() {
    return IgnorePointer(
      child: ValueListenableBuilder<_ScrubHud?>(
        valueListenable: _hud,
        builder: (context, hud, _) => hud == null || _exiting
            ? const SizedBox.shrink()
            : _ScrubHudCard(hud: hud),
      ),
    );
  }

  Widget _buildScrubRail() {
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: _chrome,
        builder: (context, chromeVisible, _) {
          if (chromeVisible || _exiting) return const SizedBox.shrink();
          return ValueListenableBuilder<_ScrubHud?>(
            valueListenable: _hud,
            builder: (context, hud, _) {
              if (hud == null) return const SizedBox.shrink();
              return Align(
                alignment: .bottomCenter,
                child: Padding(
                  padding: .only(bottom: MediaQuery.paddingOf(context).bottom),
                  child: SizedBox(
                    width: .infinity,
                    height: 2,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0x1FFFFFFF)),
                      child: FractionallySizedBox(
                        alignment: .centerLeft,
                        widthFactor: hud.duration > Duration.zero
                            ? (hud.position.inMilliseconds /
                                      hud.duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBoostBadge() {
    final l10n = context.l10n;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: _boost,
        builder: (context, boosting, _) {
          final visible = boosting && !_exiting;
          return Align(
            alignment: .topCenter,
            child: Padding(
              padding: .only(top: MediaQuery.paddingOf(context).top + 14),
              child: AnimatedSlide(
                offset: visible ? .zero : const Offset(0, -0.6),
                duration: Durations.short3,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: Durations.short3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xB80C0C0E),
                      borderRadius: .circular(16),
                      border: .all(color: const Color(0x1FFFFFFF), width: 0.5),
                    ),
                    child: Padding(
                      padding: const .fromLTRB(14, 8, 16, 8),
                      child: Row(
                        mainAxisSize: .min,
                        children: [
                          const Icon(
                            LucideIcons.fastForward,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.ui.videoPlayerSpeedBoost(
                              speed: _kBoostSpeed.toStringAsFixed(0),
                            ),
                            style: context
                                .theme
                                .typography
                                .labelLarge
                                .emphasized
                                .onSurface
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScrubBar extends StatefulWidget {
  const _ScrubBar({
    required this.progress,
    required this.semanticLabel,
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onNudge,
  });

  final ValueListenable<VideoProgress> progress;
  final String semanticLabel;
  final ValueChanged<Duration> onBegin;
  final ValueChanged<Duration> onUpdate;
  final ValueChanged<Duration> onEnd;
  final ValueChanged<Duration> onNudge;

  @override
  State<_ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<_ScrubBar>
    with SingleTickerProviderStateMixin {
  static const _kRowHeight = 28.0;
  static const _kNudge = Duration(seconds: 5);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final CurvedAnimation _pressed = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
  );

  final _percent = ValueNotifier<int>(0);
  double _lastX = 0;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_syncPercent);
    _syncPercent();
  }

  @override
  void dispose() {
    widget.progress.removeListener(_syncPercent);
    _percent.dispose();
    _pressed.dispose();
    _press.dispose();
    super.dispose();
  }

  void _syncPercent() {
    final f = widget.progress.value.fraction;
    if (f == null) return;
    _percent.value = (f * 100).round();
  }

  double get _width {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : 0;
  }

  Duration? _timeAt(double dx) {
    final p = widget.progress.value;
    final w = _width;
    if (w <= 0 || p.fraction == null) return null;
    return p.duration * (dx / w).clamp(0.0, 1.0);
  }

  void _begin(double dx) {
    final at = _timeAt(dx);
    if (at == null) return;
    _lastX = dx;
    _press.forward();
    widget.onBegin(at);
  }

  void _update(double dx) {
    final at = _timeAt(dx);
    if (at == null) return;
    _lastX = dx;
    widget.onUpdate(at);
  }

  void _finish() {
    if (!_press.isForwardOrCompleted) return;
    _press.reverse();
    final at = _timeAt(_lastX);
    if (at != null) widget.onEnd(at);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      behavior: .opaque,
      onTapDown: (d) => _begin(d.localPosition.dx),
      onTapUp: (_) => _finish(),
      onTapCancel: _finish,
      onHorizontalDragStart: (d) => _begin(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _update(d.localPosition.dx),
      onHorizontalDragEnd: (_) => _finish(),
      onHorizontalDragCancel: _finish,
      onLongPress: () {},
      child: ValueListenableBuilder<int>(
        valueListenable: _percent,
        builder: (context, percent, child) => Semantics(
          slider: true,
          label: widget.semanticLabel,
          value: '$percent%',
          onIncrease: () => widget.onNudge(_kNudge),
          onDecrease: () => widget.onNudge(-_kNudge),
          child: child,
        ),
        child: RepaintBoundary(
          child: CustomPaint(
            size: const Size(.infinity, _kRowHeight),
            painter: _ScrubPainter(
              progress: widget.progress,
              press: _pressed,
              dpr: dpr,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrubPainter extends CustomPainter {
  _ScrubPainter({
    required this.progress,
    required this.press,
    required this.dpr,
  }) : super(repaint: .merge([progress, press]));

  final ValueListenable<VideoProgress> progress;
  final Animation<double> press;
  final double dpr;

  static const _kIdleTrack = 3.0;
  static const _kPressTrack = 6.0;
  static const _kLift = 2.0;
  static const _kIdleThumb = 4.0;
  static const _kPressThumb = 7.0;

  double _snap(double v) => dpr <= 0 ? v : (v * dpr).roundToDouble() / dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final t = press.value;
    final p = progress.value;
    final f = (p.fraction ?? 0).clamp(0.0, 1.0);

    final h = _kIdleTrack + (_kPressTrack - _kIdleTrack) * t;
    final cy = _snap(size.height / 2 - _kLift * t);
    final top = _snap(cy - h / 2);
    final radius = Radius.circular(h / 2);
    final rail = RRect.fromLTRBR(0, top, size.width, top + h, radius);

    canvas.drawRRect(
      rail.inflate(0.5),
      Paint()..color = const Color(0x8C000000),
    );
    canvas.drawRRect(rail, Paint()..color = const Color(0x1FFFFFFF));

    if (f > 0) {
      final right = math.max(size.width * f, h);
      canvas.drawRRect(
        .fromLTRBR(0, top, right, top + h, radius),
        Paint()..color = Colors.white,
      );
    }

    final core = _kIdleThumb + (_kPressThumb - _kIdleThumb) * t;
    final cx = (size.width * f).clamp(core, size.width - core);
    canvas.drawCircle(Offset(cx, cy), core, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.dpr != dpr || old.progress != progress;
}

class _TimeCode extends StatelessWidget {
  const _TimeCode({required this.progress});

  final ValueListenable<VideoProgress> progress;

  static const _kShadow = [
    Shadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final known = p.duration > Duration.zero;
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: p.duration.inHours >= 1 ? 128 : 92,
          ),
          child: Row(
            mainAxisSize: .min,
            mainAxisAlignment: .end,
            children: [
              Text(
                TimeFormat.mediaDuration(p.position),
                style: context.theme.typography.labelMedium.emphasized.onSurface
                    .copyWith(
                      color: Colors.white,
                      fontFeatures: const [.tabularFigures()],
                      shadows: _kShadow,
                    ),
              ),
              if (known) ...[
                Text(
                  ' / ',
                  style: context.theme.typography.labelMedium.onSurface
                      .copyWith(
                        color: const Color(0x4DFFFFFF),
                        shadows: _kShadow,
                      ),
                ),
                Text(
                  TimeFormat.mediaDuration(p.duration),
                  style: context.theme.typography.labelMedium.onSurface
                      .copyWith(
                        color: const Color(0x9EFFFFFF),
                        fontFeatures: const [.tabularFigures()],
                        shadows: _kShadow,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScrubHud {
  const _ScrubHud({required this.position, required this.duration, this.delta});

  final Duration position;
  final Duration duration;

  final Duration? delta;
}

class _ScrubHudCard extends StatelessWidget {
  const _ScrubHudCard({required this.hud});

  final _ScrubHud hud;

  @override
  Widget build(BuildContext context) {
    final delta = hud.delta;
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -34),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x9E0E0E10),
            borderRadius: AppBorderRadius.mediumBorderRadius,
            border: .all(color: const Color(0x1FFFFFFF), width: 0.5),
          ),
          child: Padding(
            padding: const .fromLTRB(16, 9, 16, 10),
            child: Column(
              mainAxisSize: .min,
              children: [
                if (delta != null)
                  Text(
                    _formatDelta(delta),
                    style: context
                        .theme
                        .typography
                        .labelSmall
                        .emphasized
                        .onSurface
                        .copyWith(
                          color: Colors.white,
                          fontFeatures: const [.tabularFigures()],
                        ),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: .min,
                  crossAxisAlignment: .baseline,
                  textBaseline: .alphabetic,
                  children: [
                    Text(
                      TimeFormat.mediaDuration(hud.position),
                      style: context.theme.typography.titleLarge.onSurface
                          .copyWith(
                            color: Colors.white,
                            fontFeatures: const [.tabularFigures()],
                          ),
                    ),
                    if (hud.duration > Duration.zero) ...[
                      const SizedBox(width: 6),
                      Text(
                        TimeFormat.mediaDuration(hud.duration),
                        style: context.theme.typography.labelMedium.onSurface
                            .copyWith(
                              color: const Color(0x9EFFFFFF),
                              fontFeatures: const [.tabularFigures()],
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 负号用 U+2212，连字符在等宽数字里更窄
  static String _formatDelta(Duration d) {
    final sign = d.isNegative ? '−' : '+';
    return '$sign${TimeFormat.mediaDuration(d.abs())}';
  }
}

class _AmbientBar extends StatelessWidget {
  const _AmbientBar({required this.level});

  final VideoAmbientLevel level;

  static const _kHeight = 40.0;
  static const _kTrackWidth = 132.0;
  static const _kTrackHeight = 4.0;
  static const _kTrackRadius = BorderRadius.all(.circular(_kTrackHeight / 2));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBrightness = level.channel == .brightness;
    final value = level.value.clamp(0.0, 1.0);
    final label = isBrightness
        ? l10n.ui.videoPlayerBrightness
        : l10n.ui.videoPlayerVolume;

    return Center(
      child: Transform.translate(
        offset: const Offset(0, -34),
        child: Semantics(
          label: label,
          value: '${(value * 100).round()}%',
          child: Container(
            height: _kHeight,
            padding: const .only(left: 16, right: 18),
            decoration: BoxDecoration(
              color: const Color(0xB80C0C0E),
              borderRadius: .circular(_kHeight / 2),
              border: .all(color: const Color(0x1FFFFFFF), width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  _iconFor(isBrightness, value),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _kTrackWidth,
                  height: _kTrackHeight,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      borderRadius: _kTrackRadius,
                    ),
                    child: FractionallySizedBox(
                      alignment: .centerLeft,
                      widthFactor: value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: _kTrackRadius,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 26,
                  child: Text(
                    '${(value * 100).round()}',
                    textAlign: .right,
                    style: context
                        .theme
                        .typography
                        .labelLarge
                        .emphasized
                        .onSurface
                        .copyWith(
                          color: Colors.white,
                          fontFeatures: const [.tabularFigures()],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(bool isBrightness, double v) {
    if (isBrightness) {
      return v < 0.5 ? LucideIcons.sunDim : LucideIcons.sun;
    }
    if (v <= 0) return LucideIcons.volumeX;
    return v < 0.5 ? LucideIcons.volume1 : LucideIcons.volume2;
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.big = false,
    this.filled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool big;
  final bool filled;

  static const _kMinTouch = 44.0;

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 36.0;
    final touch = math.max(size, _kMinTouch);
    return Tooltip(
      message: tooltip,
      child: MInkWell(
        shape: const CircleBorder(),
        onTap: onTap,
        onLongPress: () {},
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                color: filled ? Colors.black38 : Colors.transparent,
              ),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: Colors.white, size: big ? 30 : 21),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
