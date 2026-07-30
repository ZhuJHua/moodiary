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
      expect(fullscreenOrientationsFor(9 / 16), const [DeviceOrientation.portraitUp]);
      expect(fullscreenOrientationsFor(4 / 5), const [DeviceOrientation.portraitUp]);
    });

    test('正方形按竖处理 —— 1:1 放进横屏两侧留白过大', () {
      expect(fullscreenOrientationsFor(1.0), const [DeviceOrientation.portraitUp]);
    });
  });

  group('lockOrientationsTemporarily', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') calls.add(call);
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
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      expect(calls, hasLength(1));
      expect(orientationsOf(calls.first), [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);

      release();
      // 恢复必须真的重新下发一次 —— 观察者按策略去重，清不掉去重状态就会是空操作，
      // 竖屏锁再也回不来（这是 chewie 那条路上的既有 bug）。
      expect(calls, hasLength(2));
      expect(orientationsOf(calls.last), isNotEmpty);
    });

    testWidgets('恢复函数报告「是否真的恢复了」—— 调用方据此决定要不要等旋转', (tester) async {
      // 嵌套时内层 release 一个方向请求都没发出去，调用方若照样去等「屏幕转回来」
      // 就必然吃满超时。返回值就是这个判据。
      final outer = lockOrientationsTemporarily(const [DeviceOrientation.portraitUp]);
      final inner = lockOrientationsTemporarily(const [
        DeviceOrientation.landscapeLeft,
      ]);
      expect(inner(), isFalse, reason: '计数未归零，没有下发方向');
      expect(outer(), isTrue, reason: '归零才真的把全局策略应用回去');
    });

    testWidgets('恢复函数可重复调用，只生效一次', (tester) async {
      final release = lockOrientationsTemporarily(const [DeviceOrientation.portraitUp]);
      release();
      final afterFirst = calls.length;
      release();
      release();
      expect(calls.length, afterFirst);
    });

    testWidgets('嵌套锁：内层释放不恢复，外层释放才恢复', (tester) async {
      final outer = lockOrientationsTemporarily(const [DeviceOrientation.portraitUp]);
      final inner = lockOrientationsTemporarily(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
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
            // manual 走的是**另一个方法名**（setEnabledSystemUIOverlays），
            // 只筛 setEnabledSystemUIMode 会把「点亮两条栏」那一步整个漏掉。
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
      // 只调 edgeToEdge 的话对「栏的显隐」是空操作（此刻本来就在 edgeToEdge 里），
      // 状态栏会一直藏着 —— 整个 app 从此没有状态栏。顺序不能反，也不能少。
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
