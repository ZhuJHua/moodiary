import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(fullscreenOrientationsFor(1.0), const [
        DeviceOrientation.portraitUp,
      ], reason: '正方形按竖处理：1:1 放进横屏两侧留白过大');
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

    test('锁到指定方向，恢复函数把全局策略应用回来', () {
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

    test('恢复函数报告「是否真的恢复了」—— 调用方据此决定要不要等旋转', () {
      final outer = lockOrientationsTemporarily(const [.portraitUp]);
      final inner = lockOrientationsTemporarily(const [.landscapeLeft]);
      expect(calls, hasLength(2));

      expect(inner(), isFalse, reason: '计数未归零，没有下发方向');
      expect(calls, hasLength(2), reason: '内层释放时外层还持有，不该恢复');

      expect(outer(), isTrue, reason: '归零才真的把全局策略应用回去');
      expect(calls, hasLength(3));
    });

    test('恢复函数可重复调用，只生效一次', () {
      final release = lockOrientationsTemporarily(const [.portraitUp]);
      release();
      final afterFirst = calls.length;
      release();
      release();
      expect(calls.length, afterFirst);
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

    test('进入沉浸走 immersiveSticky', () {
      final release = enterImmersiveTemporarily();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');
      release();
    });

    test('恢复必须先 manual 点亮两条栏，再回 edgeToEdge', () {
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

    test('嵌套安全：计数没归零不恢复', () {
      final a = enterImmersiveTemporarily();
      final b = enterImmersiveTemporarily();
      calls.clear();

      a();
      expect(calls, isEmpty, reason: 'b 还占着');
      b();
      expect(calls, hasLength(2));
    });

    test('恢复器幂等：重复调用不会把计数扣穿', () {
      final release = enterImmersiveTemporarily();
      release();
      calls.clear();
      release();
      release();
      expect(calls, isEmpty);
    });
  });
}
