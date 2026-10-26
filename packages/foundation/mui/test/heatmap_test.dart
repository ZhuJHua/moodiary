import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

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

        final lum = ramp.map((c) => c.computeLuminance()).toList();
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

    expect(find.byType(GestureDetector), findsNWidgets(4 * 7 - 5));
  });

  testWidgets(
    'colorOf overrides levels; null remains empty and selection works',
    (tester) async {
      final end = DateTime(2026, 8, 17);
      final colored = DateTime(2026, 8, 16);
      final visited = <DateTime>[];
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: MHeatmap(
              endDate: end,
              weeks: 1,
              levels: {colored: 1, end: 4},
              colorOf: (day) {
                visited.add(day);
                return day == colored ? const Color(0xFF123456) : null;
              },
              selected: colored,
              onDaySelected: (day) => selected = day,
              monthLabel: (month) => '${month.month}',
              semanticsLabel: 'custom colors',
            ),
          ),
        ),
      );
      final cells = find.descendant(
        of: find.byType(MHeatmap),
        matching: find.byType(Container),
      );
      expect(cells, findsNWidgets(2));
      final first =
          tester.widget<Container>(cells.first).decoration! as BoxDecoration;
      final last =
          tester.widget<Container>(cells.last).decoration! as BoxDecoration;
      expect(first.color, const Color(0xFF123456));
      final context = tester.element(cells.last);
      expect(last.color, MHeatmap.emptyColor(context));
      expect(MHeatmap.emptyColor(context), MHeatmap.levelColor(context, 0));
      expect(last.borderRadius, MHeatmap.cellBorderRadius);
      expect(
        first.border,
        Border.all(
          color: MuiTheme.of(tester.element(cells.first)).colors.onSurface,
          width: 1.6,
        ),
      );
      expect(visited, [colored, end]);
      await tester.tap(cells.last);
      expect(selected, end);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness dashed swatch paints short 1px strokes without any fill',
      (tester) async {
        final theme = buildMuiTheme(brightness: brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Center(child: MHeatmapDashedSwatch()),
          ),
        );
        final swatch = find.byType(MHeatmapDashedSwatch);
        expect(tester.getSize(swatch), const Size.square(11));
        final customPaint = tester.widget<CustomPaint>(
          find.descendant(of: swatch, matching: find.byType(CustomPaint)),
        );
        void paint(Canvas canvas) =>
            customPaint.painter!.paint(canvas, const Size.square(11));
        var strokes = 0;
        expect(
          paint,
          paints..everything((method, arguments) {
            if (method != #drawPath) return false;
            final path = arguments[0] as Path;
            final stroke = arguments[1] as Paint;
            expect(
              stroke.color.toARGB32(),
              theme.colorScheme.outlineVariant.toARGB32(),
            );
            expect(stroke.style, PaintingStyle.stroke);
            expect(stroke.strokeWidth, 1);
            expect(path.computeMetrics().single.length, inExclusiveRange(1, 2));
            // Extracted paths use float32 coordinates.
            const tolerance = 1e-5;
            final bounds = path.getBounds();
            expect(bounds.left, greaterThanOrEqualTo(.5 - tolerance));
            expect(bounds.top, greaterThanOrEqualTo(.5 - tolerance));
            expect(bounds.right, lessThanOrEqualTo(10.5 + tolerance));
            expect(bounds.bottom, lessThanOrEqualTo(10.5 + tolerance));
            strokes++;
            return true;
          }),
        );
        expect(strokes, greaterThanOrEqualTo(10));
      },
    );
  }

  testWidgets(
    'colorOf dashed empties stay unfilled and keep selection and end-date rings',
    (tester) async {
      final end = DateTime(2020, 8, 17);
      final selected = DateTime(2020, 8, 16);
      DateTime? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: MHeatmap(
              startDate: selected,
              endDate: end,
              weeks: 1,
              levels: {selected: 4, end: 4},
              colorOf: (_) => null,
              emptyCell: .dashed,
              selected: selected,
              onDaySelected: (day) => tapped = day,
              monthLabel: (month) => '${month.month}',
              semanticsLabel: 'dashed',
            ),
          ),
        ),
      );
      final map = find.byType(MHeatmap);
      final cells = find.descendant(of: map, matching: find.byType(Container));
      final swatches = find.descendant(
        of: map,
        matching: find.byType(MHeatmapDashedSwatch),
      );
      expect(cells, findsNWidgets(2));
      expect(swatches, findsNWidgets(2));
      final colors = MuiTheme.of(tester.element(map)).colors;
      final decorations = tester
          .widgetList<Container>(cells)
          .map((cell) => cell.decoration! as BoxDecoration)
          .toList();
      expect(decorations.map((decoration) => decoration.color), [null, null]);
      expect(
        decorations.first.border,
        Border.all(color: colors.onSurface, width: 1.6),
      );
      expect(
        decorations.last.border,
        Border.all(color: colors.outline, width: 1.2),
      );
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(cells.at(i)), const Size.square(11));
        expect(tester.getSize(swatches.at(i)), const Size.square(11));
        expect(decorations[i].borderRadius, MHeatmap.cellBorderRadius);
      }
      await tester.tap(swatches.first);
      expect(tapped, selected);
      await tester.tap(swatches.last);
      expect(tapped, end);
    },
  );

  testWidgets('dashed mode only affects null colorOf days through today', (
    tester,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: .light),
        home: Scaffold(
          body: MHeatmap(
            startDate: yesterday,
            endDate: tomorrow,
            weeks: 2,
            colorOf: (day) => day == yesterday ? const Color(0xFF123456) : null,
            emptyCell: .dashed,
            monthLabel: (month) => '${month.month}',
            semanticsLabel: 'future',
          ),
        ),
      ),
    );
    final cells = find.descendant(
      of: find.byType(MHeatmap),
      matching: find.byType(Container),
    );
    expect(cells, findsNWidgets(3));
    final decorations = tester
        .widgetList<Container>(cells)
        .map((cell) => cell.decoration! as BoxDecoration)
        .toList();
    expect(decorations[0].color, const Color(0xFF123456));
    expect(decorations[1].color, isNull);
    expect(
      decorations[2].color,
      MHeatmap.emptyColor(tester.element(cells.last)),
    );
    expect(find.byType(MHeatmapDashedSwatch), findsOneWidget);
  });

  testWidgets('levels mode ignores dashed empty style', (tester) async {
    final end = DateTime(2020, 8, 17);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: .light),
        home: Scaffold(
          body: MHeatmap(
            endDate: end,
            weeks: 1,
            levels: {end: 3},
            emptyCell: .dashed,
            monthLabel: (month) => '${month.month}',
            semanticsLabel: 'levels',
          ),
        ),
      ),
    );
    expect(find.byType(MHeatmapDashedSwatch), findsNothing);
    final cells = find.descendant(
      of: find.byType(MHeatmap),
      matching: find.byType(Container),
    );
    final colors = tester
        .widgetList<Container>(cells)
        .map((cell) => (cell.decoration! as BoxDecoration).color)
        .toList();
    expect(colors, [
      MHeatmap.levelColor(tester.element(cells.first), 0),
      MHeatmap.levelColor(tester.element(cells.last), 3),
    ]);
  });

  testWidgets('month labels optionally select the first day of that month', (
    tester,
  ) async {
    DateTime? selected;
    Widget heatmap(ValueChanged<DateTime>? callback) => MaterialApp(
      theme: buildMuiTheme(brightness: .light),
      home: Scaffold(
        body: MHeatmap(
          endDate: DateTime(2026, 3, 31),
          weeks: 13,
          monthLabel: (month) => 'month-${month.month}',
          semanticsLabel: 'months',
          onMonthSelected: callback,
        ),
      ),
    );
    await tester.pumpWidget(heatmap(null));
    expect(find.byType(GestureDetector), findsNothing);
    await tester.pumpWidget(heatmap((month) => selected = month));
    await tester.tap(find.text('month-2'));
    expect(selected, DateTime(2026, 2));
    await tester.tap(find.text('month-3'));
    expect(selected, DateTime(2026, 3));
  });

  testWidgets(
    'startDate hides earlier padding cells and labels in a cross-year week',
    (tester) async {
      final visited = <DateTime>[];
      final start = DateTime(2026);
      final end = DateTime(2026, 1, 10);
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: MHeatmap(
              startDate: start,
              endDate: end,
              weeks: 2,
              colorOf: (day) {
                visited.add(day);
                return null;
              },
              onDaySelected: (day) => selected = day,
              onMonthSelected: (month) => selected = month,
              monthLabel: (month) => 'month-${month.month}',
              semanticsLabel: 'bounded',
            ),
          ),
        ),
      );
      expect(visited, [
        for (var day = 1; day <= 10; day++) DateTime(2026, 1, day),
      ]);
      expect(find.text('month-12'), findsNothing);
      expect(find.text('month-1'), findsOneWidget);
      await tester.tap(find.text('month-1'));
      expect(selected, start);
      final cells = find.descendant(
        of: find.byType(MHeatmap),
        matching: find.byType(Container),
      );
      expect(cells, findsNWidgets(10));
      await tester.tap(cells.first);
      expect(selected, start);
      await tester.tap(cells.last);
      expect(selected, end);
    },
  );

  testWidgets(
    'default Me heatmap keeps its levels, cell geometry and selection border',
    (tester) async {
      final today = DateTime(2026, 8, 17);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(
            brightness: .light,
            accent: const MuiAccent.seeded(Color(0xFF2E59A7)),
          ),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: MHeatmap(
                endDate: today,
                levels: {today: 4, DateTime(2026, 8, 16): 2},
                selected: today,
                monthLabel: (month) => '${month.month}',
                semanticsLabel: 'Me',
              ),
            ),
          ),
        ),
      );
      final map = find.byType(MHeatmap);
      expect(tester.widget<MHeatmap>(map).emptyCell, MHeatmapEmptyCell.filled);
      expect(find.byType(MHeatmapDashedSwatch), findsNothing);
      final cells = find.descendant(of: map, matching: find.byType(Container));
      expect(cells, findsNWidgets(53 * 7 - 5));
      final context = tester.element(map);
      final colors = MuiTheme.of(context).colors;
      final decorations = tester
          .widgetList<Container>(cells)
          .map((cell) => cell.decoration! as BoxDecoration)
          .toList();
      expect(decorations.first.color, MHeatmap.levelColor(context, 0));
      expect(
        decorations[decorations.length - 2].color,
        MHeatmap.levelColor(context, 2),
      );
      expect(decorations.last.color, MHeatmap.levelColor(context, 4));
      expect(
        decorations.last.border,
        Border.all(color: colors.onSurface, width: 1.6),
      );
      expect(tester.getSize(cells.last), const Size.square(11));
      final rows = find.descendant(of: map, matching: find.byType(Row));
      expect(tester.getSize(rows.first), const Size(53 * 14, 7 * 14));
    },
  );

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
    expect(position.pixels, position.maxScrollExtent);
    expect(position.maxScrollExtent, greaterThan(0));
  });
}
