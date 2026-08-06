import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

const _boundaryKey = ValueKey('probe');
const _capsuleSize = Size(300, 60);

Widget _harness(List<BoxShadow>? shadows) {
  return MaterialApp(
    theme: ThemeData(colorScheme: const .dark()),
    home: RepaintBoundary(
      key: _boundaryKey,
      child: Container(
        color: Colors.white,
        alignment: .center,
        child: SizedBox.fromSize(
          size: _capsuleSize,
          child: MoodiaryGlassSurface(
            shape: const StadiumBorder(),
            shadows: shadows,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

/// 取屏幕坐标 [at] 处的 RGB。
Future<List<int>> _pixel(WidgetTester tester, Offset at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  late List<int> rgb;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: .rawRgba);
    final width = image.width;
    final offset = ((at.dy.round() * width) + at.dx.round()) * 4;
    rgb = [
      data!.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    ];
    image.dispose();
  });
  return rgb;
}

/// 取同一点在「无投影」与「默认投影」两种渲染下的像素。
///
/// `debugDisableShadows` 必须在**测试体内**还原：flutter_test 在 test body 结束时就
/// 校验绘制类 debug 变量已复位，放 tearDown 里来不及。
Future<(List<int> without, List<int> with_)> _probe(
  WidgetTester tester,
  Offset at,
) async {
  debugDisableShadows = false;
  try {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();
    final without = await _pixel(tester, at);

    await tester.pumpWidget(_harness(null)); // null = 组件的默认投影
    await tester.pumpAndSettle();
    final with_ = await _pixel(tester, at);
    return (without, with_);
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('投影不参与自己的背景模糊：胶囊内部不该因为有投影而变暗', (tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final (without, with_) = await _probe(
      tester,
      Offset(size.width / 2, size.height / 2),
    );

    // 允许一点点误差：BackdropFilter 的 sigma 24 会从胶囊外面把邻近的投影带进来
    // 一点，这是对的（真玻璃的边缘也会吃到）。但不该有整片压暗。
    for (var i = 0; i < 3; i++) {
      expect(
        (with_[i] - without[i]).abs(),
        lessThan(6),
        reason:
            '有投影 $with_ vs 无投影 $without —— 投影糊到自己的背景上了，'
            '见 _GlassShadowPainter 的注释',
      );
    }
  });

  testWidgets('投影仍然画在胶囊外面', (tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    // 胶囊下缘往下 10 px：默认投影 offset(0, 8) + blur 24 覆盖得到。
    final (without, with_) = await _probe(
      tester,
      Offset(size.width / 2, size.height / 2 + _capsuleSize.height / 2 + 10),
    );

    expect(
      with_[0],
      lessThan(without[0] - 5),
      reason: '挖空挖过头了，胶囊外面也没投影：$with_ vs $without',
    );
  });
}
