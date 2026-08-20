// 皮肤「暗室」：整块屏幕是一间暗室 —— 画面尽量大，chrome 默认不存在，操作由手指落点决定。
//
// 只有这一种形态：媒体库点缩略图、正文点全屏键，两个入口都直接推这一个独占路由。
// 不做「卡片 → 再点进铺满」的两级形态，于是纹理全程不换父，也就没有「纹理跨路由搬家闪黑」的风险。
//
// 方向按视频比例锁定（横拍锁横、竖拍锁竖），走 lockOrientationsTemporarily —— 不要直接调
// SystemChrome.setPreferredOrientations，全局竖屏锁按策略去重，绕过它就再也恢复不回来。
//
// 手势表（一个动作只有一个含义，不按落点分歧义）：
//   单击   显隐控制条            双击   播放 / 暂停
//   横拖   跳转（常速刮擦）      长按   2× 倍速，松手还原
//   竖拖   左亮度 / 右音量 / 中间下拉关闭
// 刻意没有「双击左右两边 ±10s」：跳转统一交给横拖，双击就只做播放暂停。
//
// 音量走**系统媒体音量**而不是播放器自身的 setVolume：后者只缩放这一路音轨，
// 用户用硬件键静音之后任何音量 UI 都会说谎（见 video_ambient_controller.dart）。
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
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show DeviceOrientation, HapticFeedback;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

typedef VideoSurfaceBuilder = Widget Function(VideoPlaybackPort port);

/// 全屏横拖刮擦的换算：毫秒 / 像素。
///
/// 短片跟着时长走（划满一屏 ≈ 全片 60%），长片封顶 —— 不封顶的话 10 分钟的视频划一屏
/// 就是 6 分钟，一根手指根本落不准。封顶值取一屏 ≈ 67 秒。
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
    Duration startAt = .zero,
    ValueChanged<Duration>? onExitAt,
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
    Duration startAt = .zero,
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
  State<MVideoPlayerPage> createState() => _MVideoPlayerPageState();
}

class _MVideoPlayerPageState extends State<MVideoPlayerPage>
    with WidgetsBindingObserver {
  late final MVideoPlaybackController _player;
  final _chrome = VideoChromeController();
  final _ambient = VideoAmbientController(ports: defaultVideoAmbientPorts());

  OrientationOverrideRelease? _releaseOrientation;
  List<DeviceOrientation>? _lockedTo;

  /// 沉浸模式（藏起状态栏 / 导航栏）的恢复器。
  ImmersiveOverrideRelease? _releaseImmersive;

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

  /// 下拉关闭的跟手位移。**不能走 setState** —— 那是每帧重建整个 Stack（含纹理那一支）。
  final _dragY = ValueNotifier<double>(0);

  /// 刮擦时间码。同上，跟手期间每帧都在变，必须自成一路。
  final _hud = ValueNotifier<_ScrubHud?>(null);
  VoidCallback? _unpinChrome;

  /// 长按倍速中。
  final _boost = ValueNotifier<bool>(false);
  double? _speedBeforeBoost;

  static const _kDismissThreshold = 120.0;
  static const _kBoostSpeed = 2.0;

  /// 始终等不到就无条件放行 —— 系统旋转锁定、外接屏等情形下 metrics 可能永远不变。
  static const _kRotateTimeout = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _player = MVideoPlaybackController(
      source: .file(widget.videoPath),
      portFactory: videoPlayerPortFactory,
      initialAspect: widget.initialAspect,
      // 不自动播：转场与旋转都结束后才开播。否则画面/声音在旋转期间就起来了，
      // 而那几帧被系统的旋转截图盖着，等于白解码，声音也先于画面出现。
      autoPlay: false,
    );
    // 亮度 / 音量的初值要在第一次手势之前读回来，否则第一次滑动没有基准点。
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
    // 方向落定之后才藏系统栏：藏栏本身会触发一次 metrics 变化，
    // 排在旋转编排中间会和「等它转过去」的判据搅在一起。
    _releaseImmersive ??= enterImmersiveTemporarily();
    _player.play();
    _chrome.keep();
  }

  void _onStateChanged() {
    final state = _player.state.value;
    _chrome.syncPlayIntent(state.isPlayIntent);
    // 倍速期间播放被外部打断（来电、音频焦点丢失、播完）—— 速度得跟着还原，
    // 否则下次按播放会莫名其妙以 2× 开始。
    if (!state.isPlayIntent) _endBoost();
  }

  /// 两张卡共用正中偏上那个槽位。正常情况下不会同时出现（一个是横拖、一个是竖拖），
  /// 但 ±10s 那张卡有 900ms 停留，期间开始调音量就会叠上 —— 让后来的把前一张顶掉。
  void _onAmbientChanged() {
    if (_ambient.active.value != null) _hideHud();
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
    if (currentOrientationPolicy() != .portraitOnly) {
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
    _ambient.active.removeListener(_onAmbientChanged);
    _player.state.removeListener(_onStateChanged);
    _player.geometry.removeListener(_applyOrientation);
    _unpinChrome?.call();
    _hud.dispose();
    _boost.dispose();
    _dragY.dispose();
    _releaseOrientation?.call();
    _releaseOrientation = null;
    // 兜「被外部直接 pop」的异常路径 —— 漏掉的话整个 app 从此没有状态栏。
    _releaseImmersive?.call();
    _releaseImmersive = null;
    // 亮度复位、音量恢复系统弹窗都在这里面 —— 漏掉的话整个 app 会停在播放时那个亮度上。
    _ambient.dispose();
    _chrome.dispose();
    _player.dispose();
    super.dispose();
  }

  /// 刮擦时每帧调用：只改 HUD 这一路，不动别的。
  void _showHud(Duration position, {Duration? delta}) {
    _hud.value = _ScrubHud(
      position: position,
      duration: _player.progress.value.duration,
      delta: delta,
    );
  }

  void _hideHud() => _hud.value = null;

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
    _endBoost();
    _player.pause();
    _hideHud();
    _dragY.value = 0;
    setState(() {});
    _reportExit();

    // 先请求恢复方向，**此刻还没 pop**，全屏画面仍在屏上 —— 于是用户看到的是
    // 「整个 app 带着画面转回竖屏」，而不是「先露出横着的底页」。
    final restored = _releaseOrientation?.call() ?? false;
    _releaseOrientation = null;
    // 没真的下发方向请求（嵌套计数未归零），等下去只会吃满超时。
    if (restored && _lockedTo != null) {
      await _awaitOrientation(const [.portraitUp]);
    }
    // 系统栏留到最后一刻才放回来：整段退场编排（转回竖屏）都还是沉浸的，
    // 不会在转的过程中先把状态栏亮出来。
    _releaseImmersive?.call();
    _releaseImmersive = null;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ─────────────────────────── 手势 ───────────────────────────

  void _onTapUp(TapUpDetails d) => _chrome.toggle();

  /// 双击 = 播放 / 暂停。**不再是 ±10s** —— 跳转统一交给横滑，一个动作只有一个含义。
  void _onDoubleTap() {
    final state = _player.state.value;
    if (!state.acceptsCommands) return;
    if (state is VideoCompleted) {
      _player.replay();
      return;
    }
    _player.togglePlay();
  }

  /// 长按 = 倍速。松手、手势被打断、播放被外部打断（来电 / 音频焦点丢失）都要还原速度。
  void _onLongPressStart(LongPressStartDetails d) {
    final state = _player.state.value;
    // 暂停时长按不生效：那会变成「长按开始播放」，和双击抢含义。
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

  /// 起手位置，用来算 HUD 上那行 delta。[_scrubBase] 会随手指累加，不能拿它当基准。
  Duration _scrubOrigin = .zero;

  void _onHorizontalStart(DragStartDetails d) {
    if (!_inScrubZone(d.localPosition)) return;
    final p = _player.progress.value;
    if (!p.canSeek) return;
    _scrubBase = p.position;
    _scrubOrigin = p.position;
    // 不叫醒 chrome：横划时该看的是时间码，控制栏跳出来只是遮画面。
    // 但要钉住，否则划到一半 3 秒自动隐藏会把已经显示的控件抽走。
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

  /// 手势被系统收走（来电、切后台）时 end 不会来。不收尾的话时间码会一直挂在屏上，
  /// 而且 chrome 的那个 pin 永远不释放 —— 控制条从此再也不自动隐藏。
  void _onHorizontalCancel() {
    if (_scrubBase == null) return;
    _scrubBase = null;
    _unpinChrome?.call();
    _unpinChrome = null;
    _player.cancelScrub();
    _hideHud();
  }

  /// 竖拖按落点分工：左三分之一亮度、右三分之一音量、中间三分之一下拉关闭。
  /// 落点一次定终身 —— 中途手指横移到别的区不换通道，否则调着调着会突然开始关页面。
  VideoAmbientChannel? _ambientChannel;

  void _onVerticalStart(DragStartDetails d) {
    if (_scrubBase != null) return;
    final channel = ambientChannelForX(
      d.localPosition.dx,
      MediaQuery.sizeOf(context).width,
    );
    // 通道读不到当前值（模拟器、部分 ROM 拿不到亮度）就把这三分之一还给下拉关闭 ——
    // 认领了却调不动的话，那一侧既没有反馈也关不掉页面，是个死区。
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
      // 屏幕坐标向下为正，而上滑要调大，取反。
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

  /// 手势被系统抢走（例如通知栏下拉）也要收尾，否则通道会一直停在「拖动中」。
  bool _endAmbientDrag() {
    if (_ambientChannel == null) return false;
    _ambientChannel = null;
    _ambient.end();
    return true;
  }

  /// 同上，但下拉关闭那一路还得把位移归零 —— 否则整页会卡在被拖下去的位置。
  void _onVerticalCancel() {
    if (_endAmbientDrag()) return;
    _dragY.value = 0;
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

  /// 底栏。scrim 由 0xB8 三档换成 0x94 五档并收成定高（横 78 / 竖 104）+ 安全区：
  /// 五个 stop 是为了压色带，定高是为了不再靠 padding 把渐变撑到画面下三分之一。
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
    final accent = context.theme.colors.primary;
    return Row(
      children: [
        Expanded(
          child: _ScrubBar(
            progress: _player.progress,
            accent: accent,
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
        _TimeCode(progress: _player.progress, accent: accent),
      ],
    );
  }

  /// 亮度 / 音量的调节条。chrome 藏着也要出现 —— 调节时本来就不该把控件唤回来。
  ///
  /// 淡出期间要继续画最后一次的值：直接换成空盒子会让它「啪」地消失，没有淡出可言。
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
            // 进得快、出得慢：抬手之后那一下不该像被抽走。
            duration: visible ? Durations.short2 : Durations.medium1,
            child: _AmbientBar(level: shown),
          ),
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
      // 拦下系统返回与预测式返回，改走 _requestExit 的编排（先转回竖屏再 pop）。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      // 页面自身透明：纯黑由路由的 barrierColor 提供，于是下拉关闭时内容淡出而底色始终是黑。
      backgroundColor: Colors.transparent,
      // 下拉位移只重建这一层：以前它走 setState，等于每帧把整个 Stack（含纹理那一支）重建一次。
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

  /// 刮擦时间码卡。同样自成一路：跟手期间每帧都在变。
  Widget _buildScrubHud() {
    final accent = context.theme.colors.primary;
    return IgnorePointer(
      child: ValueListenableBuilder<_ScrubHud?>(
        valueListenable: _hud,
        builder: (context, hud, _) => hud == null || _exiting
            ? const SizedBox.shrink()
            : _ScrubHudCard(hud: hud, accent: accent),
      ),
    );
  }

  /// 刮擦时贴底的一条 2dp 细进度。只在 **chrome 藏着** 时出现 ——
  /// 横划不再把整条控制栏叫出来，但「刮到哪了」总得有个全局参照。
  Widget _buildScrubRail() {
    final accent = context.theme.colors.primary;
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
                  // 压在系统手势条 / home indicator 底下就看不见了，抬到安全区之上。
                  padding: .only(bottom: MediaQuery.paddingOf(context).bottom),
                  child: SizedBox(
                    // 必须显式铺满：Align 给的是松约束，不写宽度这条轨会缩成 0。
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
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: accent),
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

  /// 长按倍速时顶部那枚牌子。刻意不放在正中那个槽位：它是**持续状态**，
  /// 而正中那一格留给瞬时反馈（刮擦时间码 / 亮度音量）。
  Widget _buildBoostBadge() {
    final l10n = context.l10n;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: _boost,
        builder: (context, boosting, _) {
          final visible = boosting && !_exiting;
          // Align 必须在最外层：AnimatedSlide 的 offset 是按**自身尺寸**的比例算的，
          // 套在铺满全屏的 Align 外面，一个 0.6 就是往上飞半个屏幕。
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

/// 自绘进度条。**刻意不用 Material Slider**：RoundSliderThumbShape 的半径不可动画、
/// trackHeight 改值会跳、overlay 那套又和「按下整条上浮」打架。
///
/// 进度是 10Hz 的（插件内部 100ms 轮询），所以这里把 progress 直接喂给 CustomPainter 的
/// repaint —— widget 树一次都不重建，只 markNeedsPaint；外面再套 RepaintBoundary，
/// 免得每 100ms 把关闭键、时间码、渐变一起重录一遍。
class _ScrubBar extends StatefulWidget {
  const _ScrubBar({
    required this.progress,
    required this.accent,
    required this.semanticLabel,
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onNudge,
  });

  final ValueListenable<VideoProgress> progress;
  final Color accent;
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
  /// 视觉 3dp，命中整行 —— 命中区与视觉解耦，不必为了好按而把轨画粗。
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

  /// 读屏用的百分比。只在整数变化时才重建（一分钟的视频约 1Hz），
  /// 不能直接跟着 10Hz 的 progress 走 —— 那会每 100ms 把语义树标脏一次。
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

  /// 落点 → 时间。时长未知（Android 的 DURATION_UNSET）时整条不可拖。
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
      // 认领长按：不接的话，按住进度条会被外面那个全屏手势当成「长按倍速」，
      // 同时这里的按压还会顺手 seek 一次。这里长按什么都不做。
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
              accent: widget.accent,
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
    required this.accent,
    required this.dpr,
  }) : super(repaint: .merge([progress, press]));

  final ValueListenable<VideoProgress> progress;
  final Animation<double> press;
  final Color accent;
  final double dpr;

  static const _kIdleTrack = 3.0;
  static const _kPressTrack = 6.0;
  static const _kLift = 2.0;
  static const _kIdleThumb = 4.0;
  static const _kPressThumb = 7.0;

  /// 对齐到物理像素。3dp 的轨和 8dp 的白点在 2.625x 这种 DPR 上不对齐就会发糊。
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

    // 0.5dp 黑底压在轨下面。**填充而不是描边** —— 0.5px 的 stroke 骑在路径上、
    // 两侧各 0.25dp，抗锯齿之后基本等于没画，而纯白画面上 12% 白的轨本来就会消失。
    canvas.drawRRect(
      rail.inflate(0.5),
      Paint()..color = const Color(0x8C000000),
    );
    canvas.drawRRect(rail, Paint()..color = const Color(0x1FFFFFFF));

    if (f > 0) {
      final right = math.max(size.width * f, h);
      canvas.drawRRect(
        .fromLTRBR(0, top, right, top + h, radius),
        Paint()..color = accent,
      );
    }

    // thumb 只是长大，**不套外环** —— 那圈光晕是 Material overlay 的遗风，
    // 在一条 3dp 的细轨上只会显得脏。
    final core = _kIdleThumb + (_kPressThumb - _kIdleThumb) * t;
    final cx = (size.width * f).clamp(core, size.width - core);
    canvas.drawCircle(Offset(cx, cy), core, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.accent != accent || old.dpr != dpr || old.progress != progress;
}

/// 时间码。等宽数字 + 固定最小宽度：不定宽的话每跳一秒轨就会被挤动一次；
/// 超过 1 小时字串变长（1:02:33），最小宽度跟着换一档。
class _TimeCode extends StatelessWidget {
  const _TimeCode({required this.progress, required this.accent});

  final ValueListenable<VideoProgress> progress;
  final Color accent;

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
              AnimatedDefaultTextStyle(
                duration: Durations.short3,
                // 刮擦中把已播时间染成强调色：手指在动的是它，不是总长。
                style: context.theme.typography.labelMedium.emphasized.onSurface
                    .copyWith(
                      color: p.draft ? accent : Colors.white,
                      fontFeatures: const [.tabularFigures()],
                      shadows: _kShadow,
                    ),
                child: Text(TimeFormat.mediaDuration(p.position)),
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

/// 刮擦 / ±10s 的时间码卡。
class _ScrubHud {
  const _ScrubHud({required this.position, required this.duration, this.delta});

  final Duration position;
  final Duration duration;

  /// 相对起手点的位移；null 则不画那一行。
  final Duration? delta;
}

class _ScrubHudCard extends StatelessWidget {
  const _ScrubHudCard({required this.hud, required this.accent});

  final _ScrubHud hud;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final delta = hud.delta;
    return Center(
      // 定量上移 34dp（不是按比例）：正中恰好是手指按住的地方，
      // 按比例的话竖屏会飘到离手指很远的位置。
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
                        .primary
                        .copyWith(fontFeatures: const [.tabularFigures()]),
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

  /// 负号用 U+2212，别用连字符 —— 等宽数字里连字符会比减号窄一截。
  static String _formatDelta(Duration d) {
    final sign = d.isNegative ? '−' : '+';
    return '$sign${TimeFormat.mediaDuration(d.abs())}';
  }
}

/// 亮度 / 音量条：屏幕正中的一枚胶囊（图标 + 条 + 数字）。
///
/// 早先是贴左右边缘的竖条，废掉了 —— 它换来的「不遮画面」在实机上没兑现：5dp 的条正好落在
/// Android 手势导航的边缘热区里，用户会本能地去摸着它拖，那一下常被系统的返回手势吃掉。
///
/// 两条通道**都用白色填充**，只靠图标区分。深色半透明底是为了在过曝画面上也读得清；
/// 这一页不用毛玻璃 —— chrome 的淡入淡出与下拉关闭都会压层，模糊会在那两个时刻退化成纯色板。
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
      // 与刮擦时间码共用同一个槽位（正中偏上 34dp）：同一时刻只会出现一张，
      // 位置一致比各占一处更稳，也不压住画面正中的主体。
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
                      // 跟手的量不做隐式动画，做了手感立刻发黏。
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

  /// 视觉尺寸保持 36，**命中区撑到 44** —— 36dp 不到无障碍最小命中标准，
  /// 而这两个键（关闭 / 播放）恰好是全屏下最要紧的两个。
  static const _kMinTouch = 44.0;

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 36.0;
    final touch = math.max(size, _kMinTouch);
    return Tooltip(
      message: tooltip,
      // 原先这里垫着一层 Material：水波画在最近的 Material 上，交给外面 Scaffold
      // 那层会画在视频纹理**底下**，等于没有反馈。MInkWell 的按压遮罩画在自己
      // 子树里，与背景无关，所以那一层撤掉了。
      child: MInkWell(
        shape: const CircleBorder(),
        onTap: onTap,
        // 认领长按，免得按住关闭键被外面那个全屏手势当成「长按倍速」。
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
