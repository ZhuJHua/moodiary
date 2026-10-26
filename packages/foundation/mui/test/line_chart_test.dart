import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Future<void> _pumpChart(
  WidgetTester tester,
  List<double?> values, {
  bool connectGaps = false,
}) async {
  final theme = buildMuiTheme(brightness: .light);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurfaceVariant: const Color(0xFF000000),
          outlineVariant: const Color(0xFFFFFFFF),
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
                connectGaps: connectGaps,
                yMin: 1,
                yMax: 5,
                ringColor: const Color(0xFFFFFFFF),
                pointColor: (_, _) => const Color(0xFFFF0000),
                semanticsLabel: 'Trend',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<bool> _hasInk(WidgetTester tester, int x, int y) async {
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
                  semanticsLabel: 'Trend',
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MLineChart)), const Size(300, 180));
      expect(
        tester.widget<MLineChart>(find.byType(MLineChart)).connectGaps,
        false,
      );
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

  for (final connectGaps in [false, true]) {
    testWidgets('connectGaps=$connectGaps controls continuity across null', (
      tester,
    ) async {
      await _pumpChart(tester, [2, null, 4], connectGaps: connectGaps);
      await tester.runAsync(() async {
        expect(await _hasInk(tester, 85, 121), connectGaps);
        expect(await _hasInk(tester, 222, 76), connectGaps);
        expect(await _hasInk(tester, 154, 104), isFalse);
        expect(await _hasInk(tester, 17, 144), isTrue);
        expect(await _hasInk(tester, 290, 53), isTrue);
      });
      await _pumpChart(tester, [2, 3, 4], connectGaps: connectGaps);
      await tester.runAsync(
        () async => expect(await _hasInk(tester, 85, 121), isTrue),
      );
    });

    testWidgets('a lone sample draws only its marker with $connectGaps', (
      tester,
    ) async {
      for (final values in <List<double?>>[
        [3],
        [null, 3, null],
      ]) {
        await _pumpChart(tester, values, connectGaps: connectGaps);
        await tester.runAsync(() async {
          expect(await _hasInk(tester, 154, 99), isTrue);
          expect(await _hasInk(tester, 85, 99), isFalse);
          expect(await _hasInk(tester, 222, 99), isFalse);
        });
      }
    });
  }

  testWidgets('top markers use the chart edge', (tester) async {
    await _pumpChart(tester, [5]);
    await tester.runAsync(() async {
      expect(await _hasInk(tester, 154, 7), isTrue);
    });
  });

  testWidgets('empty and single-value charts render without division by zero', (
    tester,
  ) async {
    await _pumpChart(tester, []);
    await _pumpChart(tester, [3]);
    expect(tester.takeException(), isNull);
  });
}
