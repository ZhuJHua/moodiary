import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('fullscreenOrientationsFor', () {
    test('横拍锁横，两个横向都给（用户左右手持都行）', () {
      expect(fullscreenOrientationsFor(16 / 9), const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      expect(fullscreenOrientationsFor(4 / 3), const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('竖拍锁竖', () {
      expect(fullscreenOrientationsFor(9 / 16), const [
        DeviceOrientation.portraitUp,
      ]);
      expect(fullscreenOrientationsFor(4 / 5), const [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('正方形按竖处理 —— 1:1 放进横屏两侧留白过大', () {
      expect(fullscreenOrientationsFor(1.0), const [
        DeviceOrientation.portraitUp,
      ]);
    });
  });

  group('lockOrientationsTemporarily', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              calls.add(call);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    List<String> orientationsOf(MethodCall call) =>
        (call.arguments as List).cast<String>();

    testWidgets('锁到指定方向，恢复函数把全局策略应用回来', (tester) async {
      final release = lockOrientationsTemporarily(const [
        .landscapeLeft,
        .landscapeRight,
      ]);
      expect(calls, hasLength(1));
      expect(orientationsOf(calls.first), [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);

      release();
      expect(calls, hasLength(2));
      expect(orientationsOf(calls.last), isNotEmpty);
    });

    testWidgets('恢复函数报告「是否真的恢复了」—— 调用方据此决定要不要等旋转', (tester) async {
      final outer = lockOrientationsTemporarily(const [.portraitUp]);
      final inner = lockOrientationsTemporarily(const [.landscapeLeft]);
      expect(inner(), isFalse, reason: '计数未归零，没有下发方向');
      expect(outer(), isTrue, reason: '归零才真的把全局策略应用回去');
    });

    testWidgets('恢复函数可重复调用，只生效一次', (tester) async {
      final release = lockOrientationsTemporarily(const [.portraitUp]);
      release();
      final afterFirst = calls.length;
      release();
      release();
      expect(calls.length, afterFirst);
    });

    testWidgets('嵌套锁：内层释放不恢复，外层释放才恢复', (tester) async {
      final outer = lockOrientationsTemporarily(const [.portraitUp]);
      final inner = lockOrientationsTemporarily(const [
        .landscapeLeft,
        .landscapeRight,
      ]);
      expect(calls, hasLength(2));

      inner();
      expect(calls, hasLength(2), reason: '内层释放时外层还持有，不该恢复');

      outer();
      expect(calls, hasLength(3));
    });
  });

  group('enterImmersiveTemporarily', () {
    late List<MethodCall> calls;

    setUp(() {
      resetImmersiveOverridesForTest();
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
              calls.add(call);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      resetImmersiveOverridesForTest();
    });

    testWidgets('进入沉浸走 immersiveSticky', (tester) async {
      final release = enterImmersiveTemporarily();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');
      release();
    });

    testWidgets('恢复必须先 manual 点亮两条栏，再回 edgeToEdge', (tester) async {
      final release = enterImmersiveTemporarily();
      calls.clear();

      release();
      expect(calls, hasLength(2));
      expect(calls.first.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect((calls.first.arguments as List).cast<String>(), [
        'SystemUiOverlay.top',
        'SystemUiOverlay.bottom',
      ]);
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
    });

    testWidgets('嵌套安全：计数没归零不恢复', (tester) async {
      final a = enterImmersiveTemporarily();
      final b = enterImmersiveTemporarily();
      calls.clear();

      a();
      expect(calls, isEmpty, reason: 'b 还占着');
      b();
      expect(calls, hasLength(2));
    });

    testWidgets('恢复器幂等：重复调用不会把计数扣穿', (tester) async {
      final release = enterImmersiveTemporarily();
      release();
      calls.clear();
      release();
      release();
      expect(calls, isEmpty);
    });
  });
}
