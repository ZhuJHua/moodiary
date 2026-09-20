import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

const _boundaryKey = ValueKey('probe');
const _capsuleSize = Size(300, 60);

const _destinations = [
  MNavDestination(icon: Icon(LucideIcons.bookText), label: '日记'),
  MNavDestination(icon: Icon(LucideIcons.image), label: '媒体'),
  MNavDestination(icon: Icon(LucideIcons.astroid), label: '助手'),
];

final _mui = buildMuiTheme(brightness: Brightness.dark);
final _navMui = buildMuiTheme(brightness: Brightness.light);

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

Future<List<List<int>>> _pixels(WidgetTester tester, List<Offset> at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final rgb = <List<int>>[];
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: .rawRgba))!;
    final width = image.width;
    for (final point in at) {
      final offset = ((point.dy.round() * width) + point.dx.round()) * 4;
      rgb.add([
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      ]);
    }
    image.dispose();
  });
  return rgb;
}

Future<(List<List<int>> without, List<List<int>> with_)> _probe(
  WidgetTester tester,
  List<Offset> at,
) async {
  debugDisableShadows = false;
  try {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();
    final without = await _pixels(tester, at);

    await tester.pumpWidget(_harness(null));
    await tester.pumpAndSettle();
    final with_ = await _pixels(tester, at);
    return (without, with_);
  } finally {
    debugDisableShadows = true;
  }
}

Future<double> _bandHeight(
  WidgetTester tester, {
  required double bottomInset,
}) async {
  late double band;
  await tester.pumpWidget(
    MuiTheme(
      data: _navMui,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: .only(bottom: bottomInset)),
          child: Scaffold(
            extendBody: true,
            body: Builder(
              builder: (context) {
                band = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand();
              },
            ),
            bottomNavigationBar: MNavBar(
              destinations: _destinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              action: const MNavAction(icon: Icon(LucideIcons.pencilLine)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return band;
}

void main() {
  testWidgets('投影不参与自己的背景模糊：胶囊内部不该因为有投影而变暗', (tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final (without, with_) = await _probe(tester, [
      Offset(size.width / 2, size.height / 2),
      Offset(size.width / 2, size.height / 2 + _capsuleSize.height / 2 + 10),
    ]);

    for (var i = 0; i < 3; i++) {
      expect(
        (with_[0][i] - without[0][i]).abs(),
        lessThan(6),
        reason:
            '有投影 ${with_[0]} vs 无投影 ${without[0]} —— 投影糊到自己的背景上了，'
            '见 _GlassShadowPainter 的注释',
      );
    }

    expect(
      with_[1][0],
      lessThan(without[1][0] - 5),
      reason: '挖空挖过头了，胶囊外面也没投影：${with_[1]} vs ${without[1]}',
    );
  });

  testWidgets('底栏让开底部安全区', (tester) async {
    final without = await _bandHeight(tester, bottomInset: 0);
    final with48 = await _bandHeight(tester, bottomInset: 48);
    expect(with48 - without, 48, reason: '底栏没有让开安全区：$without vs $with48');
  });
}
