// 皮肤「暗室」：整块屏幕是一间暗室 —— 画面尽量大，chrome 默认不存在，操作由手指落点决定。
//
// 只有这一种形态：媒体库点缩略图、正文点全屏键，两个入口都直接推这一个独占路由。
// 不做「卡片 → 再点进铺满」的两级形态，于是纹理全程不换父，也就没有「纹理跨路由搬家闪黑」的风险。
//
// 方向按视频比例锁定（横拍锁横、竖拍锁竖），走 lockOrientationsTemporarily —— 不要直接调
// SystemChrome.setPreferredOrientations，全局竖屏锁按策略去重，绕过它就再也恢复不回来。
//
// 不提供音量控制：setVolume 只缩放播放器自身音量，用户用硬件键静音后任何音量 UI 都会说谎。
//
// —— 方向编排（这是「退出时先看到 app 横着、再猛地转回竖屏」的根治）——
// 进场：路由转场**跑完之后**才锁方向。锁在 initState 里的话，旋转会和转场动画同时进行。
// 退场：拦下 pop → 藏控件 + 暂停 → 先请求恢复方向 → **等屏幕真的转回来** → 才 pop。
// 现状之所以难看，是因为方向恢复排在 dispose（即反向动画之后），整整晚了一个转场。
// 「转完了」没有官方回调，只能拿 metrics 做谓词 + 超时兜底（刻意不猜系统旋转动画时长）。
// 平板 / 折叠屏（策略 unrestricted）整套编排不启用：系统按物理姿态自己转，等不到确定终态。
//
// 背景一律纯黑，不铺模糊封面 —— 模糊封面只用在正文内联播放器（那里是嵌在纸面里的一块，
// 需要柔化边界）；全屏是独占场景，纯黑最不抢画面。封面只在首帧上屏前当 poster 用（contain，
// 不模糊），避免一段黑闪。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../../basic/loading.dart';
import 'video_chrome_controller.dart';
import 'video_playback_controller.dart';
import 'video_playback_port.dart';
import 'video_playback_state.dart';
import 'video_player_port_impl.dart';

typedef VideoSurfaceBuilder = Widget Function(VideoPlaybackPort port);

Widget defaultVideoSurfaceBuilder(VideoPlaybackPort port) =>
    port is VideoPlayerPluginPort ? port.buildSurface() : const SizedBox.shrink();

class MoodiaryVideoPlayerPage extends StatefulWidget {
  const MoodiaryVideoPlayerPage({
    super.key,
    required this.videoPath,
    this.coverPath,
    this.initialAspect,
    this.startAt = Duration.zero,
    this.onExitAt,
    this.surfaceBuilder = defaultVideoSurfaceBuilder,
  });

  final String videoPath;

  /// 视频封面（缩略图）。用来铺信箱区的高斯模糊底 —— 不用黑色。
  final String? coverPath;

  /// 显示朝向的宽高比，来自封面文件头（缩略图插件已按 rotation 归一化）。
  /// 有了它就能在推路由前定好朝向，页面不会先竖着出现再转过去。
  final double? initialAspect;

  /// 从正文交接过来时的续播位置。
  final Duration startAt;

  /// 退出时的播放位置。**在 dispose 里回调**，因此下拉关闭、关闭键、系统返回键三条路都覆盖到
  /// —— 靠路由结果传会漏掉系统返回。正文据此把位置灌回 webview 里那个 `<video>`。
  final ValueChanged<Duration>? onExitAt;

  final VideoSurfaceBuilder surfaceBuilder;

  /// 打开播放页。[initialAspect] 决定锁横还是锁竖，**必须在 push 之前拿到**，
  /// 否则只能等 initialized，用户会看到一次旋转。
  static Future<void> show(
    BuildContext context, {
    required String videoPath,
    String? coverPath,
    double? initialAspect,
    Duration startAt = Duration.zero,
    ValueChanged<Duration>? onExitAt,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: Durations.medium2,
        reverseTransitionDuration: Durations.medium1,
        pageBuilder: (_, _, _) => MoodiaryVideoPlayerPage(
          videoPath: videoPath,
          coverPath: coverPath,
          initialAspect: initialAspect,
          startAt: startAt,
          onExitAt: onExitAt,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// 按媒体文件名打开 —— 媒体库点缩略图与正文点全屏键**共用**这一个入口。
  ///
  /// 比例必须在 push 之前拿到：播放页按它锁横 / 锁竖，等到 initialized 才知道的话
  /// 用户会看到一次旋转。封面由缩略图插件生成，它按 rotation 归一化过宽高，
  /// 因此比 VideoPlayerValue.size 更可靠（后者不应用 rotationCorrection）。
  /// showByName 里读封面是个真实的异步缝：同一缩略图快速双击会推两个路由，
  /// 方向 override 计数变 2，退场时 release 不归零 ⇒ 一个方向请求都发不出去。
  static bool _opening = false;

  static Future<void> showByName(
    BuildContext context, {
    required String name,
    Duration startAt = Duration.zero,
    ValueChanged<Duration>? onExitAt,
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
    );
  }

  /// getRealPath 内部对文件名做 substring(6, 42)，名字不合预期长度会同步抛 RangeError
  /// （仓内已有多处同款隐患）。拿不到封面只是没有模糊底与预判朝向，不该崩。
  static String? _coverPathOf(String name) {
    try {
      return AppFiles.getRealPath('thumbnail', name);
    } catch (_) {
      return null;
    }
  }

  /// 只读图片文件头（不解码整图）且带 LRU 缓存，开销极低。
  static Future<double?> _coverAspect(String? coverPath) async {
    if (coverPath == null || !File(coverPath).existsSync()) return null;
    try {
      return await ImageSizeManager().getAspectRatioAsync(coverPath);
    } catch (_) {
      return null;
    }
  }

  @override
  State<MoodiaryVideoPlayerPage> createState() => _MoodiaryVideoPlayerPageState();
}

class _MoodiaryVideoPlayerPageState extends State<MoodiaryVideoPlayerPage>
    with WidgetsBindingObserver {
  late final MoodiaryVideoPlaybackController _player;
  final _chrome = VideoChromeController();

  OrientationOverrideRelease? _releaseOrientation;
  List<DeviceOrientation>? _lockedTo;

  /// 进场转场是否已跑完。转场期间不许锁方向（旋转与转场动画同时进行必然难看），
  /// 期间拿到的比例只记下来，门开了补锁。
  bool _entryDone = false;
  List<DeviceOrientation>? _pendingLock;

  /// 旋转编排进行中。**只有它为真时**才把退场请求排队 —— 否则（例如进场转场刚开始就按返回）
  /// 应当立刻退场，此时还没锁方向，全程竖屏，不该强迫用户看完一次「转横再转竖」。
  bool _rotationInFlight = false;

  bool _exiting = false;
  bool _exitReported = false;
  Completer<void>? _orientationWaiter;
  List<DeviceOrientation>? _waitFor;

  /// 下拉关闭的跟手位移。
  double _dragY = 0;

  /// 瞬时 HUD（±10s / 拖动时间码）。chrome 藏着时它也要能出现。
  String? _hud;
  VoidCallback? _unpinChrome;

  static const _kSkip = Duration(seconds: 10);
  static const _kDismissThreshold = 120.0;

  /// 始终等不到就无条件放行 —— 系统旋转锁定、外接屏等情形下 metrics 可能永远不变。
  static const _kRotateTimeout = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _player = MoodiaryVideoPlaybackController(
      source: VideoSource.file(widget.videoPath),
      portFactory: videoPlayerPortFactory,
      initialAspect: widget.initialAspect,
      // 不自动播：转场与旋转都结束后才开播。否则画面/声音在旋转期间就起来了，
      // 而那几帧被系统的旋转截图盖着，等于白解码，声音也先于画面出现。
      autoPlay: false,
    );
    WidgetsBinding.instance.addObserver(this);
    _player.state.addListener(_onStateChanged);
    _player.geometry.addListener(_applyOrientation);
    _player.initialize().then((_) {
      if (mounted && widget.startAt > Duration.zero) _player.seekTo(widget.startAt);
    });
  }

  bool _routeHooked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeHooked) return;
    _routeHooked = true;
    final anim = ModalRoute.of(context)?.animation;
    if (anim == null || anim.status == AnimationStatus.completed) {
      _openEntryGate();
      return;
    }
    void onStatus(AnimationStatus s) {
      if (s != AnimationStatus.completed) return;
      anim.removeStatusListener(onStatus);
      _openEntryGate();
    }

    anim.addStatusListener(onStatus);
  }

  /// 转场跑完 → 允许锁方向。进场的旋转从这一刻才开始。
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

  /// 封面飞完 + 方向落定 = 舞台就绪，这才开播。
  void _onStageReady() {
    if (!mounted || _exiting || _stageReady) return;
    _stageReady = true;
    _player.play();
    _chrome.keep();
  }

  void _onStateChanged() {
    _chrome.syncPlayIntent(_player.state.value.isPlayIntent);
  }

  List<DeviceOrientation>? _orientationsForCurrentAspect() {
    final aspect = _player.geometry.value.naturalAspect;
    return aspect == null ? null : fullscreenOrientationsFor(aspect);
  }

  /// 比例到手（封面预读或 initialized 补上）。门没开就先记下，别在转场期间旋转。
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
    // 平板 / 折叠屏展开态放开四向，锁与等待都不成立 —— 整套编排跳过。
    if (currentOrientationPolicy() != DeviceOrientationPolicy.portraitOnly) {
      _onStageReady();
      return;
    }
    // 已经是目标朝向（竖拍视频的常态）⇒ 不会有旋转，也就不必进入编排。
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

  /// 「转完了」的判据：metrics 谓词命中 → 再等一帧 → 放行；始终等不到则超时无条件放行。
  ///
  /// **刻意不去等系统旋转动画播完**。那个时长没有任何可观测信号，各家 ROM 差异又大，
  /// 只能猜；而它纯粹是装饰性的：Android 用旋转前的截图盖住重排，metrics 到达时动画可能还在跑，
  /// 此时 pop ⇒ 反向转场与封面飞行播在截图底下、看不见（观感退化成「转完直接是网格」，
  /// 不会坏，只是少一段动画）。用一个必然要按机型调的魔数去换这段动画不划算。
  Future<void> _awaitOrientation(List<DeviceOrientation> want) async {
    if (_isCurrentOrientation(want)) return;
    final waiter = Completer<void>();
    _orientationWaiter = waiter;
    _waitFor = want;
    await Future.any([waiter.future, Future<void>.delayed(_kRotateTimeout)]);
    _orientationWaiter = null;
    _waitFor = null;
    if (!mounted) return;
    // 等一帧让新 metrics 走完一次布局，避免 pop 与重排撞在同一帧。
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
    // 正常路径已在 _beginExit 里上报（那时调用方 await 的 future 还没 resolve）；
    // 这里只兜「被外部直接 pop」的异常路径，靠 _exitReported 保持幂等。
    _reportExit();
    WidgetsBinding.instance.removeObserver(this);
    _player.state.removeListener(_onStateChanged);
    _player.geometry.removeListener(_applyOrientation);
    _unpinChrome?.call();
    _releaseOrientation?.call();
    _releaseOrientation = null;
    _chrome.dispose();
    _player.dispose();
    super.dispose();
  }

  void _flashHud(String text) {
    setState(() => _hud = text);
    _chrome.keep();
  }

  bool _exitRequested = false;

  /// 退出位置必须在**决定 pop 的那一刻**上报：调用方 await 的是 push 的 future，
  /// 它在 pop 那一刻就 resolve 了 —— 放在 dispose 里上报，正文那边的位置回灌永远收不到。
  void _reportExit() {
    if (_exitReported) return;
    _exitReported = true;
    widget.onExitAt?.call(_player.progress.value.position);
  }

  void _close() => _requestExit();

  /// 四条退出路径（关闭键 / 下拉 / 系统返回 / 预测式返回）统一入口。
  void _requestExit() {
    if (_exiting) return;
    _exitRequested = true;
    // 进场的旋转还在跑：此刻插进去会让「转横」和「转竖」叠在一起。等它落定再退。
    if (_rotationInFlight) return;
    _beginExit();
  }

  Future<void> _beginExit() async {
    if (_exiting) return;
    _exiting = true;
    // 先把屏上一切动的东西停掉：旋转期间 Flutter 侧不该有任何动画，
    // 且带着下拉位移去让系统截图必然难看。
    _player.pause();
    setState(() {
      _hud = null;
      _dragY = 0;
    });
    _reportExit();

    // 先请求恢复方向，**此刻还没 pop**，全屏画面仍在屏上 —— 于是用户看到的是
    // 「整个 app 带着画面转回竖屏」，而不是「先露出横着的底页」。
    final restored = _releaseOrientation?.call() ?? false;
    _releaseOrientation = null;
    // 没真的下发方向请求（嵌套计数未归零），等下去只会吃满超时。
    if (restored && _lockedTo != null) {
      await _awaitOrientation(const [DeviceOrientation.portraitUp]);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ─────────────────────────── 手势 ───────────────────────────

  void _onTapUp(TapUpDetails d) => _chrome.toggle();

  void _onDoubleTapDown(TapDownDetails d) {
    final w = MediaQuery.sizeOf(context).width;
    final forward = d.localPosition.dx > w / 2;
    _player.skip(forward ? _kSkip : -_kSkip);
    _flashHud(forward ? '+10s' : '−10s');
  }

  /// 横拖 = 刮擦。**左右各让出系统手势插图宽度**：iOS 左缘返回与 Android 预测性返回都从边缘起手，
  /// 在那里开始刮擦会被系统抢走。插图宽度必须读 MediaQuery，某些 ROM 允许用户调宽，写死 24dp 不够。
  bool _inScrubZone(Offset local) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final w = MediaQuery.sizeOf(context).width;
    final left = insets.left > 0 ? insets.left : 24.0;
    final right = insets.right > 0 ? insets.right : 24.0;
    return local.dx > left && local.dx < w - right;
  }

  Duration? _scrubBase;

  void _onHorizontalStart(DragStartDetails d) {
    if (!_inScrubZone(d.localPosition)) return;
    final p = _player.progress.value;
    if (!p.canSeek) return;
    _scrubBase = p.position;
    _unpinChrome = _chrome.pin();
    _player.beginScrub(p.position);
  }

  void _onHorizontalUpdate(DragUpdateDetails d) {
    final base = _scrubBase;
    if (base == null) return;
    final total = _player.progress.value.duration;
    if (total <= Duration.zero) return;
    // 全屏宽 ≈ 全片长的 60%，避免一划到底。
    final w = MediaQuery.sizeOf(context).width;
    final deltaMs = (d.primaryDelta ?? 0) / w * total.inMilliseconds * 0.6;
    final next = base + Duration(milliseconds: deltaMs.round());
    _scrubBase = next;
    _player.updateScrub(next);
    _flashHud(TimeFormat.mediaPosition(_player.progress.value.position, total));
  }

  void _onHorizontalEnd(DragEndDetails d) {
    final base = _scrubBase;
    _scrubBase = null;
    _unpinChrome?.call();
    _unpinChrome = null;
    if (base == null) return;
    _player.endScrub(_player.progress.value.position);
    setState(() => _hud = null);
  }

  void _onVerticalUpdate(DragUpdateDetails d) {
    if (_scrubBase != null) return;
    setState(() => _dragY = (_dragY + (d.primaryDelta ?? 0)).clamp(0.0, 400.0));
  }

  void _onVerticalEnd(DragEndDetails d) {
    if (_dragY > _kDismissThreshold || (d.primaryVelocity ?? 0) > 700) {
      _requestExit();
      return;
    }
    setState(() => _dragY = 0);
  }

  // ─────────────────────────── 画面 ───────────────────────────

  Widget _buildSurface() {
    return ValueListenableBuilder<VideoGeometry>(
      valueListenable: _player.geometry,
      builder: (context, geo, _) {
        final port = _player.port;
        final aspect = geo.naturalAspect;
        final surface = port == null
            ? const SizedBox.shrink()
            // generation 做 key：retry 换了端口才会真正换纹理。
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

  /// 首帧上屏前的 poster：与画面同样 contain 居中，不模糊，信箱区仍是纯黑。
  /// 平台不提供 first-frame-rendered 信号，撤出时机由核心的 coverVisible 决定。
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
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
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

  // ─────────────────────────── chrome ───────────────────────────

  Widget _buildChrome() {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: _chrome,
      builder: (context, visible0, _) {
        // 退场期间一律藏起来：旋转那几帧屏上不该有任何控件。
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
                    icon: Icons.close_rounded,
                    tooltip: l10n.videoPlayerClose,
                    onTap: _close,
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar(l10n)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 12,
        top: 28,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: [0, 0.55, 1],
          colors: [Color(0xB8000000), Color(0x47000000), Color(0x00000000)],
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
                    ? Icons.replay_rounded
                    : (state.isPlayIntent
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                tooltip: completed
                    ? l10n.videoPlayerReplay
                    : (state.isPlayIntent ? l10n.videoPlayerPause : l10n.videoPlayerPlay),
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

  Widget _buildScrubber(AppLocalizations l10n) {
    return ValueListenableBuilder<VideoProgress>(
      valueListenable: _player.progress,
      builder: (context, p, _) {
        final fraction = p.fraction;
        return Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: p.draft ? 5 : 3,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Theme.of(context).colorScheme.primary,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: p.draft ? 8 : 6),
                ),
                child: Slider(
                  value: fraction ?? 0,
                  // 时长未知时禁用而不是画 0 —— Android 的 DURATION_UNSET 路径真的会给这种文件。
                  onChanged: fraction == null
                      ? null
                      : (v) {
                          _chrome.keep();
                          _player.updateScrub(p.duration * v);
                        },
                  onChangeStart: fraction == null
                      ? null
                      : (v) {
                          _unpinChrome = _chrome.pin();
                          _player.beginScrub(p.duration * v);
                        },
                  onChangeEnd: fraction == null
                      ? null
                      : (v) {
                          _unpinChrome?.call();
                          _unpinChrome = null;
                          _player.endScrub(p.duration * v);
                        },
                  label: l10n.videoPlayerProgress,
                ),
              ),
            ),
            Text(
              TimeFormat.mediaPosition(p.position, p.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 状态叠层：加载 / 缓冲 / 播完 / 错误。chrome 藏着它也要出现。
  Widget _buildStateLayer() {
    final l10n = context.l10n;
    if (_exiting) return const SizedBox.shrink();
    return ValueListenableBuilder<VideoPlaybackState>(
      valueListenable: _player.state,
      builder: (context, state, _) => switch (state) {
        VideoError(:final canRetry) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 34),
              const SizedBox(height: 10),
              Text(
                l10n.videoPlayerLoadFailed,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (canRetry) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _player.retry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: Text(l10n.videoPlayerRetry),
                ),
              ],
            ],
          ),
        ),
        _ when state.isBusy => const Center(child: MoodiaryLoading(color: Colors.white)),
        VideoCompleted() || VideoReady() => Center(
          child: _RoundIcon(
            icon: state is VideoCompleted
                ? Icons.replay_rounded
                : Icons.play_arrow_rounded,
            tooltip: state is VideoCompleted
                ? l10n.videoPlayerReplay
                : l10n.videoPlayerPlay,
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
      // 拦下系统返回与预测式返回，改走 _requestExit 的编排（先转回竖屏再 pop）。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final fade = (1 - _dragY / 400).clamp(0.4, 1.0);
    return Scaffold(
      // 页面自身透明：纯黑由路由的 barrierColor 提供，于是下拉关闭时内容淡出而底色始终是黑。
      backgroundColor: Colors.transparent,
      body: Opacity(
        opacity: fade,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSurface(),
              _buildPoster(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onTapUp,
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: () {},
                onHorizontalDragStart: _onHorizontalStart,
                onHorizontalDragUpdate: _onHorizontalUpdate,
                onHorizontalDragEnd: _onHorizontalEnd,
                onVerticalDragUpdate: _onVerticalUpdate,
                onVerticalDragEnd: _onVerticalEnd,
              ),
              _buildStateLayer(),
              _buildChrome(),
              if (_hud != null)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: AppBorderRadius.mediumBorderRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        _hud!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 36.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? Colors.black38 : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: big ? 30 : 21),
          ),
        ),
      ),
    );
  }
}
