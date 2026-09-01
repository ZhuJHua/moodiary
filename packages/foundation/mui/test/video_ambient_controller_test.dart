// 亮度 / 音量控制器的纯逻辑测试。假端口 + testWidgets 的 FakeAsync 时钟
// （沿用 video_playback_machine_test 的做法：不引 fake_async 这个 transitive 依赖）。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

class FakeAmbientPort implements VideoAmbientChannelPort {
  FakeAmbientPort({this.initial = 0.5});

  /// null 模拟「平台读不到」。
  final double? initial;

  final _ctl = StreamController<double>.broadcast();
  final writes = <double>[];

  /// 卡住写入用来观察单飞合并。
  Completer<void>? gate;
  bool released = false;
  int reads = 0;

  void emitExternal(double v) => _ctl.add(v);

  @override
  Future<double?> read() async {
    reads += 1;
    return initial;
  }

  @override
  Future<void> write(double value) async {
    writes.add(value);
    final g = gate;
    if (g != null) await g.future;
  }

  @override
  Stream<double> get changes => _ctl.stream;

  @override
  Future<void> release() async {
    released = true;
    await _ctl.close();
  }
}

typedef Rig = ({
  VideoAmbientController controller,
  FakeAmbientPort brightness,
  FakeAmbientPort volume,
});

/// 建台 → 跑用例 → **在用例体内**收尾。dispose 必须发生在测试体结束前：
/// binding 的「不许留悬挂 timer」检查排在 tearDown 之前，放 addTearDown 里救不回来。
void ambientTest(
  String name,
  Future<void> Function(WidgetTester tester, Rig rig) body, {
  double? brightnessInitial = 0.5,
  double? volumeInitial = 0.4,
}) {
  testWidgets(name, (tester) async {
    final brightness = FakeAmbientPort(initial: brightnessInitial);
    final volume = FakeAmbientPort(initial: volumeInitial);
    final rig = (
      controller: VideoAmbientController(
        ports: {.brightness: brightness, .volume: volume},
        linger: const Duration(milliseconds: 100),
        echoWindow: const Duration(milliseconds: 50),
      ),
      brightness: brightness,
      volume: volume,
    );
    try {
      await body(tester, rig);
    } finally {
      rig.controller.dispose();
      await tester.pump();
    }
  });
}

void main() {
  group('ambientChannelForX', () {
    test('左中右三等分，中间一段不认领（留给下拉关闭）', () {
      expect(ambientChannelForX(10, 300), VideoAmbientChannel.brightness);
      expect(ambientChannelForX(150, 300), isNull);
      expect(ambientChannelForX(290, 300), VideoAmbientChannel.volume);
    });

    test('边界落在中间段，不会误触发', () {
      expect(ambientChannelForX(100, 300), isNull);
      expect(ambientChannelForX(200, 300), isNull);
    });

    test('宽度为 0（首帧还没量出来）不崩也不认领', () {
      expect(ambientChannelForX(0, 0), isNull);
    });
  });

  group('VideoAmbientController', () {
    ambientTest('prime 读初值并挂监听，读到之后通道才算就绪', (tester, rig) async {
      expect(rig.controller.isReady(.volume), isFalse);
      rig.controller.prime();
      await tester.pump();

      expect(rig.brightness.reads, 1);
      expect(rig.controller.valueOf(.brightness), 0.5);
      expect(rig.controller.valueOf(.volume), 0.4);
    });

    ambientTest('读不到值的通道判为不可用，滑动不写也不显示 HUD', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      expect(rig.controller.isReady(.brightness), isFalse);
      rig.controller.begin(.brightness);
      rig.controller.dragBy(.brightness, 0.2);
      await tester.pump();

      expect(rig.brightness.writes, isEmpty);
      expect(rig.controller.active.value, isNull);
    }, brightnessInitial: null);

    ambientTest('上滑增大、下滑减小，并写到端口', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.controller.begin(.volume);
      rig.controller.dragBy(.volume, 0.25);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), closeTo(0.65, 1e-9));

      rig.controller.dragBy(.volume, -0.15);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), closeTo(0.5, 1e-9));
      expect(rig.volume.writes.last, closeTo(0.5, 1e-9));
    });

    ambientTest('按下就出 HUD，停手后延时收起', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.controller.begin(.brightness);
      expect(
        rig.controller.active.value?.channel,
        VideoAmbientChannel.brightness,
      );

      rig.controller.end();
      expect(rig.controller.active.value, isNotNull, reason: '停手不该立刻消失');

      await tester.pump(const Duration(milliseconds: 60));
      expect(rig.controller.active.value, isNotNull, reason: 'linger 未到不该收起');
      await tester.pump(const Duration(milliseconds: 60));
      expect(rig.controller.active.value, isNull);
    });

    ambientTest('顶到上限后继续上滑不攒欠账，回拖立刻响应', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.controller.begin(.brightness);
      rig.controller.dragBy(.brightness, 3.0); // 划过头
      await tester.pump();
      expect(rig.controller.valueOf(.brightness), 1.0);

      rig.controller.dragBy(.brightness, -0.1);
      await tester.pump();
      // 攒了欠账的话这里还会停在 1.0。
      expect(rig.controller.valueOf(.brightness), closeTo(0.9, 1e-9));
    });

    ambientTest('下限同理', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.controller.begin(.volume);
      rig.controller.dragBy(.volume, -3.0);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), 0.0);

      rig.controller.dragBy(.volume, 0.2);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), closeTo(0.2, 1e-9));
    });

    ambientTest('跟手期间写入单飞合并：只发首个与最后一个', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.volume.gate = Completer<void>();
      rig.controller.begin(.volume);
      for (var i = 0; i < 6; i++) {
        rig.controller.dragBy(.volume, 0.02);
      }
      await tester.pump();
      expect(rig.volume.writes.length, 1, reason: '第一次写还卡着，后续只该排队');

      rig.volume.gate!.complete();
      await tester.pump();
      expect(rig.volume.writes.length, 2, reason: '排队里只保留最后一个值');
      expect(rig.volume.writes.last, closeTo(0.52, 1e-9));
    });

    ambientTest('回声窗口内的端口回报被丢掉（系统音量分档会把手指值拽回最近一档）', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.controller.begin(.volume);
      rig.controller.dragBy(.volume, 0.23);
      rig.controller.end();
      await tester.pump();
      final mine = rig.controller.valueOf(.volume);

      rig.volume.emitExternal(0.6); // 平台把 0.63 落到了 0.6 档
      await tester.pump();
      expect(rig.controller.valueOf(.volume), mine);

      await tester.pump(const Duration(milliseconds: 60)); // 窗口过期
      rig.volume.emitExternal(0.6);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), 0.6);
    });

    ambientTest('硬件音量键（外部变化）要弹我们的 HUD —— 系统弹窗被关掉了', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();

      rig.volume.emitExternal(0.9);
      await tester.pump();
      expect(rig.controller.active.value?.channel, VideoAmbientChannel.volume);
      expect(rig.controller.active.value?.value, 0.9);
    });

    ambientTest('外部改亮度只静默同步，不弹 HUD（用户是在系统控制中心里改的，那儿本来就有反馈）', (
      tester,
      rig,
    ) async {
      rig.controller.prime();
      await tester.pump();

      rig.brightness.emitExternal(0.8);
      await tester.pump();
      expect(rig.controller.valueOf(.brightness), 0.8);
      expect(rig.controller.active.value, isNull);
    });

    ambientTest('初值迟到：按下时还没读到，读到之后以那一刻为基准', (tester, rig) async {
      rig.controller.prime(); // 刻意不 pump，read 还没完成

      rig.controller.begin(.volume);
      rig.controller.dragBy(.volume, 0.3); // 这一段作废
      expect(rig.volume.writes, isEmpty);

      await tester.pump(); // 初值 0.4 落地
      rig.controller.dragBy(.volume, 0.1);
      await tester.pump();
      expect(rig.controller.valueOf(.volume), closeTo(0.5, 1e-9));
    });

    ambientTest('dispose 让端口收尾（亮度复位 / 音量恢复系统弹窗），之后不再写入', (tester, rig) async {
      rig.controller.prime();
      await tester.pump();
      rig.controller.begin(.volume);

      rig.controller.dispose();
      await tester.pump();
      expect(rig.brightness.released, isTrue);
      expect(rig.volume.released, isTrue);

      final before = rig.volume.writes.length;
      rig.controller.dragBy(.volume, 0.5);
      rig.controller.end();
      await tester.pump();
      expect(rig.volume.writes.length, before);
    });
  });
}
