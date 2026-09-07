import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_diary/src/presentation/widget/timeline_tile.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

Diary diary({
  String title = 'T',
  DiaryMood mood = .neutral,
  DiaryWeather? weather,
  List<String> tags = const [],
  List<String> audio = const [],
  List<String> video = const [],
}) => Diary(
  id: 'test',
  title: title,
  content: '',
  contentText: 'body',
  time: DateTime(2026, 7, 20, 9, 15),
  lastModified: DateTime(2026, 7, 20, 9, 15),
  show: true,
  mood: mood,
  weather: weather,
  imageName: const [],
  audioName: audio,
  videoName: video,
  tags: tags,
  type: DiaryType.tiptap.value,
);

Place place() => Place(
  id: 'p',
  name: '厦门 环岛路',
  latitude: 1,
  longitude: 2,
  lastModified: DateTime(2026),
);

Category cat() =>
    Category(id: 'a', categoryName: 'work', lastModified: DateTime(2026));

Widget wrap(Widget child) => MuiTheme(
  data: _mui,
  child: MaterialApp(
    home: Scaffold(body: ListView(children: [child])),
  ),
);

DiaryTimelineTile tile({
  Diary? d,
  bool dayStart = true,
  bool breakBefore = false,
  Category? category,
  Place? place,
  bool showCategoryLabel = true,
  bool selecting = false,
  bool selected = false,
  bool hasAbove = false,
  DiaryMood? moodBelow,
}) {
  final value = d ?? diary();
  return DiaryTimelineTile(
    diary: value,
    stamp: value.time,
    dayStart: dayStart,
    breakBefore: breakBefore,
    category: category,
    place: place,
    showCategoryLabel: showCategoryLabel,
    selecting: selecting,
    selected: selected,
    hasAbove: hasAbove,
    moodBelow: moodBelow,
  );
}

void main() {
  testWidgets('renders inside a ListView without layout error', (t) async {
    await t.pumpWidget(wrap(tile(category: cat())));
    expect(t.takeException(), isNull);
  });

  testWidgets('day column shows the day number only on the day start', (
    t,
  ) async {
    await t.pumpWidget(wrap(tile(dayStart: true)));
    expect(find.text('20'), findsOneWidget);

    await t.pumpWidget(wrap(tile(dayStart: false)));
    expect(find.text('20'), findsNothing);
  });

  testWidgets('shows the clock time of the grouping stamp', (t) async {
    await t.pumpWidget(wrap(tile()));
    expect(find.textContaining('9:15'), findsOneWidget);
  });

  testWidgets('shows weather when weather is set', (t) async {
    await t.pumpWidget(
      wrap(
        tile(
          d: diary(
            weather: const DiaryWeather(icon: '100', temp: '22', text: '晴'),
          ),
        ),
      ),
    );
    expect(find.textContaining('晴'), findsOneWidget);
  });

  testWidgets('category label follows showCategoryLabel', (t) async {
    await t.pumpWidget(wrap(tile(category: cat(), showCategoryLabel: true)));
    expect(find.text('work'), findsOneWidget);

    await t.pumpWidget(wrap(tile(category: cat(), showCategoryLabel: false)));
    expect(find.text('work'), findsNothing);
  });

  testWidgets('selecting overlays a corner mark in place of the category', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(tile(category: cat(), selecting: true, selected: true)),
    );
    expect(find.byType(DiarySelectMark), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('work'), findsNothing);
  });

  testWidgets('unselected entries still get an empty mark', (t) async {
    await t.pumpWidget(
      wrap(tile(category: cat(), selecting: true, selected: false)),
    );
    expect(find.byType(DiarySelectMark), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsNothing);
  });

  testWidgets('footer shows tags, location and media chips', (t) async {
    await t.pumpWidget(
      wrap(
        tile(
          d: diary(
            tags: const ['旅行', '海'],
            audio: const ['a.m4a'],
            video: const ['video-1.mp4'],
          ),
          place: place(),
        ),
      ),
    );
    expect(find.text('#旅行'), findsOneWidget);
    expect(find.text('#海'), findsOneWidget);
    expect(find.text('厦门 环岛路'), findsOneWidget);
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
    expect(find.byIcon(LucideIcons.video), findsOneWidget);
  });

  testWidgets('extra tags collapse into a +N counter', (t) async {
    await t.pumpWidget(wrap(tile(d: diary(tags: const ['a', 'b', 'c', 'd']))));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('title is optional — body still renders without it', (t) async {
    await t.pumpWidget(wrap(tile(d: diary(title: ''))));
    expect(t.takeException(), isNull);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('the axis does not jump colour at the seam between two rows', (
    t,
  ) async {
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    const boundaryKey = ValueKey('axis-probe');
    final top = diary(title: '', mood: .negative);
    final bottom = diary(title: '', mood: .positive);

    await t.pumpWidget(
      MuiTheme(
        data: _mui,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: Column(
                mainAxisSize: .min,
                children: [
                  DiaryTimelineTile(
                    key: const ValueKey('a'),
                    diary: top,
                    stamp: top.time,
                    dayStart: true,
                    breakBefore: false,
                    moodBelow: bottom.mood,
                  ),
                  DiaryTimelineTile(
                    key: const ValueKey('b'),
                    diary: bottom,
                    stamp: bottom.time,
                    dayStart: true,
                    breakBefore: false,
                    hasAbove: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final seam = t.getBottomLeft(find.byKey(const ValueKey('a'))).dy;
    final boundary =
        t.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    // toImage 必须跑在 runAsync 里，否则在 fake async 下永不完成
    final data = await t.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: .rawRgba);
      return (bytes: bytes!, width: image.width);
    });
    final bytes = data!.bytes;
    final width = data.width;

    // 轴心 x：日期列 30 + 间隙 8 + 轴列 20 的中点。
    const axisX = 48;
    (int, int, int) pixelAt(int y) {
      final offset = (y * width + axisX) * 4;
      return (
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }

    final above = pixelAt(seam.round() - 3);
    final below = pixelAt(seam.round() + 3);
    final delta = [
      (above.$1 - below.$1).abs(),
      (above.$2 - below.$2).abs(),
      (above.$3 - below.$3).abs(),
    ].reduce((a, b) => a > b ? a : b);

    expect(
      delta,
      lessThan(40),
      reason: '接缝两侧轴线颜色应当连续，实测 above=$above below=$below',
    );
  });

  testWidgets('mood colors are pairwise distinct', (t) async {
    final colors = {for (final m in DiaryMood.values) diaryMoodColor(m)};
    expect(colors.length, DiaryMood.values.length);
  });

  testWidgets('天气图标取和风天气码，不是通用的云', (tester) async {
    // 101 = 和风天气码「多云」
    await tester.pumpWidget(
      wrap(
        tile(
          d: diary(
            weather: const DiaryWeather(icon: '101', temp: '26', text: '多云'),
          ),
        ),
      ),
    );
    expect(find.byIcon(qweatherIcon('101')!), findsOneWidget);
    expect(find.byIcon(LucideIcons.cloud), findsNothing);
  });

  testWidgets('认不出的天气码退回通用的云', (tester) async {
    await tester.pumpWidget(
      wrap(
        tile(
          d: diary(
            weather: const DiaryWeather(icon: 'nope', temp: '26', text: '?'),
          ),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.cloud), findsOneWidget);
  });
}
