// 状态机的纯逻辑测试。用假端口手推快照走转移表 —— 不需要插件桩，也不需要真设备。
//
// 时间推进借 testWidgets 的 FakeAsync 时钟（tester.pump(d)）：不引 fake_async
// 这个 transitive 依赖，也不用真等 250/600ms。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

class FakePort implements VideoPlaybackPort {
  FakePort({this.failInitialize = false});

  final bool failInitialize;
  final _ctl = StreamController<VideoPortSnapshot>.broadcast();
  final calls = <String>[];

  VideoPortSnapshot _snap = .empty;
  bool disposed = false;

  @override
  Stream<VideoPortSnapshot> get snapshots => _ctl.stream;

  @override
  VideoPortSnapshot get snapshot => _snap;

  void emit(VideoPortSnapshot s) {
    _snap = s;
    if (!_ctl.isClosed) _ctl.add(s);
  }

  /// 就绪快照的便捷构造。
  void ready({
    Duration position = .zero,
    Duration duration = const Duration(seconds: 60),
    bool playing = false,
    bool buffering = false,
    bool completed = false,
    int width = 1920,
    int height = 1080,
    int rotation = 0,
    String? error,
  }) => emit(
    VideoPortSnapshot(
      isInitialized: error == null,
      isPlaying: playing,
      isBuffering: buffering,
      isCompleted: completed,
      position: position,
      duration: duration,
      width: width,
      height: height,
      rotationDegrees: rotation,
      errorMessage: error,
    ),
  );

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    if (failInitialize) throw StateError('boom');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async =>
      calls.add('seekTo:${position.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume:$volume');

  @override
  Future<void> setPlaybackSpeed(double speed) async =>
      calls.add('setSpeed:$speed');

  @override
  Future<void> setLooping(bool looping) async =>
      calls.add('setLooping:$looping');

  @override
  Future<void> dispose() async {
    disposed = true;
    await _ctl.close();
  }
}

void main() {
  late List<FakePort> ports;
  MVideoPlaybackController? c;

  MVideoPlaybackController build({
    bool autoPlay = false,
    bool failInitialize = false,
    double? initialAspect,
  }) {
    ports = <FakePort>[];
    return c = MVideoPlaybackController(
      source: const .file('/tmp/a.mp4'),
      autoPlay: autoPlay,
      initialAspect: initialAspect,
      portFactory: (_) {
        final p = FakePort(failInitialize: failInitialize);
        ports.add(p);
        return p;
      },
    );
  }

  setUp(VideoPlaybackArbiter.resetForTest);
  tearDown(() {
    c?.dispose();
    c = null;
  });

  group('初始化', () {
    testWidgets('就绪未播是 Ready，不是 Paused —— 两者在平台 value 上同形', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready();
      await tester.pump();
      expect(ctl.state.value, isA<VideoReady>());
    });

    testWidgets('autoPlay 就绪即播，且回声窗口内不许被旧快照打回', (tester) async {
      final ctl = build(autoPlay: true);
      await ctl.initialize();
      // 就绪快照里 isPlaying 还是 false（play 尚未生效，100ms 轮询先报了一张旧的）。
      ports.first.ready();
      await tester.pump();
      expect(ports.first.calls, contains('play'));
      expect(
        ctl.state.value,
        isA<VideoPlaying>(),
        reason: '命令已发、平台未回声的窗口内必须屏蔽 isPlaying=false，否则播放键会闪一下',
      );

      ports.first.ready(playing: true); // 平台回声到了
      await tester.pump();
      expect(ctl.state.value, isA<VideoPlaying>());
    });

    testWidgets('initialize 抛错进 Error，且可重试', (tester) async {
      final ctl = build(failInitialize: true);
      await ctl.initialize();
      await tester.pump();
      final s = ctl.state.value;
      expect(s, isA<VideoError>());
      expect((s as VideoError).kind, VideoErrorKind.initialize);
      expect(s.canRetry, isTrue);
    });

    testWidgets('看门狗超时兜住「既不回快照也不报错」的初始化', (tester) async {
      final ctl = build();
      await ctl.initialize();
      expect(ctl.state.value, isA<VideoInitializing>());
      await tester.pump(const Duration(seconds: 13));
      expect(ctl.state.value, isA<VideoError>());
    });
  });

  group('几何', () {
    testWidgets('封面给的初始比例让首帧就有正确朝向，不必等 initialized', (tester) async {
      final ctl = build(initialAspect: 9 / 16);
      expect(ctl.geometry.value.naturalAspect, closeTo(9 / 16, 0.001));
      expect(ctl.geometry.value.isPortrait, isTrue);
    });

    testWidgets('rotation 90 要交换宽高 —— 这正是 value.aspectRatio 不做的修正', (
      tester,
    ) async {
      final ctl = build();
      await ctl.initialize();
      // 编码朝向是 1920×1080（横），但带 90° 旋转 → 实际显示是竖的。
      ports.first.ready(width: 1920, height: 1080, rotation: 90);
      await tester.pump();
      expect(ctl.geometry.value.naturalAspect, closeTo(1080 / 1920, 0.001));
      expect(ctl.geometry.value.isPortrait, isTrue);
    });
  });

  group('拖动不回弹', () {
    testWidgets('scrub 期间画的是目标位，落库前平台位置被屏蔽', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(position: const Duration(seconds: 5));
      await tester.pump();

      ctl.beginScrub(const Duration(seconds: 40));
      expect(ctl.state.value, isA<VideoSeeking>());
      expect(ctl.progress.value.position, const Duration(seconds: 40));
      expect(ctl.progress.value.draft, isTrue);

      // 平台还在报旧位置（100ms 轮询要过一拍）——绝不能让它把显示拽回去。
      ports.first.ready(position: const Duration(seconds: 5));
      await tester.pump();
      expect(ctl.progress.value.position, const Duration(seconds: 40));
    });

    testWidgets('一次拖动只发两次 state 通知（begin + settle）', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(position: const Duration(seconds: 5));
      await tester.pump();

      var notifications = 0;
      void count() => notifications += 1;
      ctl.state.addListener(count);

      ctl.beginScrub(const Duration(seconds: 10));
      for (var i = 10; i < 40; i += 2) {
        ctl.updateScrub(Duration(seconds: i));
      }
      await ctl.endScrub(const Duration(seconds: 40));
      ports.first.ready(position: const Duration(seconds: 40));
      await tester.pump();

      ctl.state.removeListener(count);
      expect(notifications, 2);
    });

    testWidgets('平台位置追上目标即落定，回到拖动前的意图', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(position: const Duration(seconds: 5), playing: true);
      await tester.pump();
      expect(ctl.state.value, isA<VideoPlaying>());

      ctl.beginScrub(const Duration(seconds: 30));
      await ctl.endScrub(const Duration(seconds: 30));
      ports.first.ready(position: const Duration(seconds: 30), playing: true);
      await tester.pump();
      expect(ctl.state.value, isA<VideoPlaying>());
      expect(ctl.progress.value.draft, isFalse);
    });

    testWidgets('平台迟迟不追上时，600ms 兜底放开跟随', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(position: .zero);
      await tester.pump();

      await ctl.seekTo(const Duration(seconds: 30));
      expect(ctl.state.value, isA<VideoSeeking>());
      await tester.pump(const Duration(milliseconds: 700));
      expect(ctl.state.value, isNot(isA<VideoSeeking>()));
    });

    testWidgets('时长未知时不许 seek', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(duration: .zero);
      await tester.pump();
      expect(ctl.progress.value.canSeek, isFalse);
      expect(ctl.progress.value.fraction, isNull);

      await ctl.seekTo(const Duration(seconds: 10));
      expect(ctl.state.value, isNot(isA<VideoSeeking>()));
      expect(ports.first.calls.where((e) => e.startsWith('seekTo')), isEmpty);
    });
  });

  group('缓冲抖动', () {
    testWidgets('短于 250ms 的 isBuffering 不进 Buffering 态', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(playing: true);
      await tester.pump();

      ports.first.ready(playing: true, buffering: true);
      await tester.pump(const Duration(milliseconds: 150));
      ports.first.ready(playing: true, buffering: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ctl.state.value, isA<VideoPlaying>());
    });

    testWidgets('持续 250ms 才进 Buffering，并记住恢复意图', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(playing: true);
      await tester.pump();

      ports.first.ready(playing: true, buffering: true);
      await tester.pump(const Duration(milliseconds: 300));
      final s = ctl.state.value;
      expect(s, isA<VideoBuffering>());
      expect((s as VideoBuffering).resumeIntent, isTrue);
      expect(s.isBusy, isTrue);
    });

    testWidgets('Seeking 期间不许显示 spinner', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(playing: true);
      await tester.pump();

      ctl.beginScrub(const Duration(seconds: 20));
      // 两端 seek 都会让 isBuffering 闪一下，跟着画 spinner 就是每拖一次闪一次。
      ports.first.ready(
        playing: false,
        buffering: true,
        position: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(ctl.state.value, isA<VideoSeeking>());
      expect(ctl.state.value.isBusy, isFalse);
    });
  });

  group('播完与外部转移', () {
    testWidgets('播完锁定 Completed，中途那帧 isPlaying=false 不会被误判成 Paused', (
      tester,
    ) async {
      final ctl = build(autoPlay: true);
      await ctl.initialize();
      ports.first.ready(playing: true, position: const Duration(seconds: 59));
      await tester.pump();

      // 插件对 completed 的处理是 pause().then(seekTo(duration)) 这条跨帧链。
      ports.first.ready(
        playing: false,
        completed: true,
        position: const Duration(seconds: 60),
      );
      await tester.pump();
      expect(ctl.state.value, isA<VideoCompleted>());

      ports.first.ready(playing: false, position: const Duration(seconds: 60));
      await tester.pump();
      expect(ctl.state.value, isA<VideoCompleted>(), reason: '锁定后忽略后续噪声');
    });

    testWidgets('外部自行翻 isPlaying 也要接受（焦点丢失 / 回前台自动续播）', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(playing: true);
      await tester.pump();
      expect(ctl.state.value, isA<VideoPlaying>());

      // 我们没发任何命令，平台自己暂停了。
      ports.first.ready(playing: false, position: const Duration(seconds: 3));
      await tester.pump();
      expect(
        ctl.state.value,
        isA<VideoPaused>(),
        reason: '播过之后就是 Paused 而非 Ready',
      );
    });
  });

  group('错误与重试', () {
    testWidgets('平台错误擦掉 value，但 resumeFrom 要留住', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready(playing: true, position: const Duration(seconds: 12));
      await tester.pump();

      ports.first.ready(error: 'decoder died');
      await tester.pump();
      final s = ctl.state.value as VideoError;
      expect(s.kind, VideoErrorKind.playback);
      expect(s.resumeFrom, const Duration(seconds: 12));
    });

    testWidgets('retry 换新 port 实例并推进 generation', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready();
      await tester.pump();
      final gen1 = ctl.geometry.value.generation;

      ports.first.ready(error: 'decoder died');
      await tester.pump();
      await ctl.retry();
      await tester.pump();

      expect(ports, hasLength(2), reason: '同实例的第二个 initialized 会 assert，必须换新的');
      expect(ports.first.disposed, isTrue);
      ports.last.ready();
      await tester.pump();
      expect(ctl.geometry.value.generation, greaterThan(gen1));
    });
  });

  group('释放', () {
    testWidgets('dispose 后所有命令静默 no-op，不抛异常', (tester) async {
      final ctl = build();
      await ctl.initialize();
      ports.first.ready();
      await tester.pump();

      ctl.dispose();
      c = null;
      await tester.pump();

      await ctl.play();
      await ctl.pause();
      await ctl.seekTo(const Duration(seconds: 5));
      await ctl.setVolume(0.5);
      await ctl.retry();
      ctl.beginScrub(const Duration(seconds: 5));
      ctl.cancelScrub();
      expect(ports.first.disposed, isTrue);
    });
  });

  group('仲裁', () {
    testWidgets('第二个实例开播会把第一个顶成暂停', (tester) async {
      final first = build(autoPlay: true);
      await first.initialize();
      ports.first.ready(playing: true);
      await tester.pump();
      final firstPort = ports.first;
      expect(first.state.value, isA<VideoPlaying>());

      late FakePort secondPort;
      final second = MVideoPlaybackController(
        source: const .file('/tmp/b.mp4'),
        autoPlay: true,
        portFactory: (_) => secondPort = FakePort(),
      );
      await second.initialize();
      // 第二个也得真的就绪才会走到 play → 才会去抢仲裁。
      secondPort.ready();
      await tester.pump();

      expect(firstPort.calls, contains('pause'));
      second.dispose();
    });
  });
}
