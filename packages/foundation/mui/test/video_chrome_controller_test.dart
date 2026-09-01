// 控制条显隐。时间推进借 testWidgets 的 FakeAsync 时钟（同仓内其它视频测试的做法）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  group('VideoChromeController', () {
    testWidgets('播放中 3 秒后自动隐藏；暂停中不隐藏', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);

      chrome.syncPlayIntent(true);
      expect(chrome.value, isTrue);
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);

      chrome.syncPlayIntent(false);
      expect(chrome.value, isTrue, reason: '暂停时要显示出来');
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isTrue, reason: '没有控制条的暂停画面是个死胡同');
    });

    testWidgets('点画面：播放中显着就收起，藏着就叫回来', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);
      chrome.syncPlayIntent(true);

      chrome.toggle();
      expect(chrome.value, isFalse);
      chrome.toggle();
      expect(chrome.value, isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('pin 期间不自动隐藏，释放后重新起表', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);
      chrome.syncPlayIntent(true);

      final release = chrome.pin();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isTrue);

      release();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);
    });

    testWidgets('pin(reveal: false) 不把藏着的控件叫出来 —— 刮擦走的就是这条', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);
      chrome.syncPlayIntent(true);
      chrome.toggle(); // 收起
      expect(chrome.value, isFalse);

      final release = chrome.pin(reveal: false);
      expect(chrome.value, isFalse, reason: '横划不该把整条控制栏叫出来');
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);

      release();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);
    });

    testWidgets('pin(reveal: false) 时已显示的控件要留着，不许中途被抽走', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);
      chrome.syncPlayIntent(true);
      expect(chrome.value, isTrue);

      final release = chrome.pin(reveal: false);
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isTrue, reason: '划到一半控件消失是最难受的');

      release();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);
    });

    testWidgets('释放器幂等：重复调用不会把计数扣穿', (tester) async {
      final chrome = VideoChromeController();
      addTearDown(chrome.dispose);
      chrome.syncPlayIntent(true);

      final a = chrome.pin();
      final b = chrome.pin();
      a();
      a();
      a();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isTrue, reason: 'b 还钉着');

      b();
      await tester.pump(const Duration(seconds: 4));
      expect(chrome.value, isFalse);
    });
  });
}
