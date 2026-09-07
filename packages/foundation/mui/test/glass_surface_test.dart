import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

const _boundaryKey = ValueKey('probe');
const _capsuleSize = Size(300, 60);

final _mui = buildMuiTheme(brightness: Brightness.dark);

Widget _harness(List<BoxShadow>? shadows) {
  return MuiTheme(
    data: _mui,
    child: MaterialApp(
      theme: _mui,
      home: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          color: Colors.white,
          alignment: .center,
          child: SizedBox.fromSize(
            size: _capsuleSize,
            child: MGlassSurface(
              shape: const StadiumBorder(),
              shadows: shadows,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

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

Future<(List<int> without, List<int> with_)> _probe(
  WidgetTester tester,
  Offset at,
) async {
  debugDisableShadows = false;
  try {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();
    final without = await _pixel(tester, at);

    await tester.pumpWidget(_harness(null));
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
