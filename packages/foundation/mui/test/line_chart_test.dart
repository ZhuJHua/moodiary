import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Future<void> pumpChart(WidgetTester tester, List<double?> values) async {
  final theme = buildMuiTheme(brightness: .light);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurfaceVariant: const Color(0xFF000000),
        ),
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('chart-image'),
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: SizedBox(
              width: 300,
              child: MLineChart(
                values: values,
                yMin: 1,
                yMax: 5,
                ringColor: const Color(0xFFFFFFFF),
                pointColor: (_, _) => const Color(0xFFFF0000),
                semanticsLabel: 'Trend',
                tooltipBuilder: (i) => 'sample $i: ${values[i]}',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<bool> hasInk(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('chart-image')),
  );
  final image = await boundary.toImage();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var ink = false;
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -2; dx <= 2; dx++) {
      final offset = ((y + dy) * image.width + x + dx) * 4;
      if (data.getUint8(offset) < 200 ||
          data.getUint8(offset + 1) < 200 ||
          data.getUint8(offset + 2) < 200) {
        ink = true;
      }
    }
  }
  image.dispose();
  return ink;
}

void main() {
  testWidgets('skeleton replaces the whole chart with one sized rounded bone', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: MSkeleton(
              enabled: enabled,
              child: SizedBox(
                width: 300,
                child: MLineChart(
                  height: 180,
                  values: const [2, 4],
                  yMin: 1,
                  yMax: 5,
                  pointColor: (_, _) => const Color(0xFFFF0000),
                  tooltipBuilder: (_) => 'sample',
                  semanticsLabel: 'Trend',
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MLineChart)), const Size(300, 180));
      final bones = find.byWidgetPredicate((widget) => widget is Bone);
      expect(bones, enabled ? findsOneWidget : findsNothing);
      expect(
        find.descendant(
          of: find.byType(MLineChart),
          matching: find.byType(CustomPaint),
        ),
        enabled ? findsNothing : findsOneWidget,
      );
      if (enabled) {
        expect(tester.getSize(bones), const Size(300, 180));
      }
    }
  });

  testWidgets(
    'null breaks the painted line; lone samples retain their markers',
    (tester) async {
      await pumpChart(tester, [2, null, 4]);
      await tester.runAsync(() async {
        expect(await hasInk(tester, 85, 121), isFalse);
        expect(await hasInk(tester, 17, 144), isTrue);
        expect(await hasInk(tester, 290, 53), isTrue);
      });
      await pumpChart(tester, [2, 3, 4]);
      await tester.runAsync(
        () async => expect(await hasInk(tester, 85, 121), isTrue),
      );
      await pumpChart(tester, [null, 3, null]);
      await tester.runAsync(() async {
        expect(await hasInk(tester, 154, 99), isTrue);
        expect(await hasInk(tester, 85, 121), isFalse);
      });
    },
  );

  testWidgets('top markers use the chart edge; tooltip overlays the plot', (
    tester,
  ) async {
    await pumpChart(tester, [5]);
    await tester.runAsync(() async {
      expect(await hasInk(tester, 154, 7), isTrue);
    });
    await tester.tap(find.byType(MLineChart));
    await tester.pump();
    final chart = tester.getRect(find.byType(MLineChart));
    final bubble = tester.getRect(
      find.byKey(const ValueKey('line-chart-tooltip')),
    );
    expect(bubble.top, chart.top);
    expect(bubble.bottom, greaterThan(chart.top + 7));
    expect(chart.height, 220);
  });

  testWidgets('tap and drag select nearest index including missing samples', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpChart(tester, [2, null, 4]);
    final origin = tester.getTopLeft(find.byType(MLineChart));
    await tester.tapAt(origin + const Offset(150, 120));
    await tester.pump();
    expect(find.text('sample 1: null'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Trend')),
      matchesSemantics(label: 'Trend', value: 'sample 1: null'),
    );
    final gesture = await tester.startGesture(origin + const Offset(150, 120));
    await gesture.moveTo(origin + const Offset(290, 120));
    await gesture.up();
    await tester.pump();
    expect(find.text('sample 2: 4.0'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'empty and single-value charts remain selectable without division by zero',
    (tester) async {
      await pumpChart(tester, []);
      await tester.tap(find.byType(MLineChart));
      await tester.pump();
      expect(find.byKey(const ValueKey('line-chart-tooltip')), findsNothing);
      await pumpChart(tester, [3]);
      await tester.tap(find.byType(MLineChart));
      await tester.pump();
      expect(find.text('sample 0: 3.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
