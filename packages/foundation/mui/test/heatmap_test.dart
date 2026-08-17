import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

/// 相邻两级之间最小的通道距离。20 是实测出来的失败点：把色阶写成「primary 按透明度叠
/// 在卡片上」时，有彩档的 L0 与 L1 正好差 20，肉眼分不出来。
const int _kMinChannelGap = 25;

int _maxChannelDelta(Color a, Color b) {
  int d(double x, double y) => ((x - y).abs() * 255).round();
  return [
    d(a.r, b.r),
    d(a.g, b.g),
    d(a.b, b.b),
  ].reduce((x, y) => x > y ? x : y);
}

Future<List<Color>> _rampOf(
  WidgetTester tester,
  Brightness brightness,
  MuiAccent accent,
) async {
  late List<Color> ramp;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMuiTheme(brightness: brightness, accent: accent),
      home: Builder(
        builder: (context) {
          ramp = [for (var i = 0; i < 5; i++) MHeatmap.levelColor(context, i)];
          return const SizedBox();
        },
      ),
    ),
  );
  return ramp;
}

void main() {
  // 灰度档的 primary 是纯黑 / 纯白，跨度天然拉满，只测它等于没测 —— 真正会塌的是有彩档
  // （primary 是 tone-40 / tone-80，离 surfaceContainerHighest 近得多）。
  const accents = [
    ('灰度', MuiAccent.neutral()),
    ('蓝', MuiAccent.seeded(Color(0xFF2E59A7))),
    ('橄榄', MuiAccent.seeded(Color(0xFF6B7A3A))),
    ('洋红', MuiAccent.seeded(Color(0xFFB33C86))),
  ];

  for (final brightness in Brightness.values) {
    for (final (name, accent) in accents) {
      testWidgets('$brightness · $name 档五级色阶两两可分', (tester) async {
        final ramp = await _rampOf(tester, brightness, accent);

        expect(ramp.toSet().length, 5, reason: '五级不能有重复色');
        for (var i = 0; i < ramp.length - 1; i++) {
          expect(
            _maxChannelDelta(ramp[i], ramp[i + 1]),
            greaterThanOrEqualTo(_kMinChannelGap),
            reason: 'L$i 与 L${i + 1} 挨得太近，梯度会读成一片',
          );
        }
      });

      testWidgets('$brightness · $name 档色阶单调', (tester) async {
        final ramp = await _rampOf(tester, brightness, accent);
        final lum = ramp.map((c) => c.computeLuminance()).toList();
        // 浅色主题往深走，深色主题往亮走 —— 方向不同，但必须一路同向。
        final rising = lum.last > lum.first;
        for (var i = 0; i < lum.length - 1; i++) {
          expect(
            rising ? lum[i + 1] > lum[i] : lum[i + 1] < lum[i],
            isTrue,
            reason: 'L$i → L${i + 1} 掉头了',
          );
        }
      });
    }
  }

  testWidgets('网格铺满 weeks × 7，今天之后的格子留空占位', (tester) async {
    // 2026-08-17 是周一，所以末列里周二到周六共 5 天在未来。
    final today = DateTime(2026, 8, 17);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: MHeatmap(
              endDate: today,
              weeks: 4,
              levels: {today: 3},
              monthLabel: (m) => '${m.month}',
              semanticsLabel: 'heatmap',
              onDaySelected: (_) {},
            ),
          ),
        ),
      ),
    );

    // 可点的格子 = 4 × 7 − 5 个未来占位。
    expect(find.byType(GestureDetector), findsNWidgets(4 * 7 - 5));
  });

  testWidgets('初始滚动位置贴最右（今天），不靠 post-frame 跳', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: MHeatmap(
              endDate: DateTime(2026, 8, 17),
              levels: const {},
              monthLabel: (m) => '${m.month}',
              semanticsLabel: 'heatmap',
            ),
          ),
        ),
      ),
    );

    final scrollable = tester.widget<Scrollable>(
      find.descendant(
        of: find.byType(MHeatmap),
        matching: find.byType(Scrollable),
      ),
    );
    final position = scrollable.controller!.position;
    // 第一帧就在最右：没有「先渲染一年前、下一帧才跳过来」的那一下闪烁。
    expect(position.pixels, position.maxScrollExtent);
    expect(position.maxScrollExtent, greaterThan(0));
  });
}
