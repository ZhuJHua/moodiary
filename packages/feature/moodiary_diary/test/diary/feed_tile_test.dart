import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

DiarySummary diary({
  String title = 'T',
  String text = 'body',
  DiaryMood? mood,
  List<String> images = const [],
  List<String> videos = const [],
  List<String> audios = const [],
  DiaryWeather? weather,
}) => diarySummaryFromDiary(
  Diary(
    id: 'test',
    title: title,
    content: '',
    contentText: text,
    time: DateTime(2026, 7, 20, 9, 15),
    lastModified: DateTime(2026, 7, 20, 9, 15),
    show: true,
    mood: mood,
    weather: weather,
    imageName: images,
    audioName: audios,
    videoName: videos,
    type: DiaryType.tiptap.value,
  ),
);

Place place() => Place(
  id: 'p',
  name: '厦门 环岛路',
  latitude: 1,
  longitude: 2,
  lastModified: DateTime(2026),
);

Widget wrap(Widget child) => MuiTheme(
  data: _mui,
  child: TranslationProvider(
    child: MaterialApp(
      home: Scaffold(body: ListView(children: [child])),
    ),
  ),
);

void main() {
  late Directory mediaDirectory;
  setUpAll(() {
    mediaDirectory = Directory.systemTemp.createTempSync('moodiary-media-');
    PlatformService.get().applicationSupportPath = mediaDirectory.path;
  });
  tearDownAll(() => mediaDirectory.deleteSync(recursive: true));

  testWidgets('renders text-only entry inside a ListView without error', (
    t,
  ) async {
    await t.pumpWidget(wrap(DiaryFeedTile(diary: diary(title: '标题在这'))));
    expect(t.takeException(), isNull);
    expect(find.textContaining('标题在这', findRichText: true), findsOneWidget);
  });

  testWidgets('untitled entry promotes the body to the headline', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(title: '', text: '只有正文'),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.textContaining('只有正文'), findsOneWidget);
  });

  testWidgets('meta line carries date, weather and place in one line', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(
            weather: const DiaryWeather(icon: '100', temp: '26', text: '晴'),
          ),
          place: place(),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final meta = t.widget<Text>(find.textContaining('26°'));
    expect(find.byIcon(qweatherIcon('100')!), findsOneWidget);
    expect(meta.textSpan!.toPlainText(), contains('厦门 环岛路'));
    expect(meta.maxLines, 1);
    expect(meta.overflow, TextOverflow.ellipsis);
    expect(meta.textSpan!.toPlainText(), isNot(contains('晴')));
  });

  testWidgets('weather without a temperature shows the icon only', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(
            weather: const DiaryWeather(icon: '100', text: '晴'),
          ),
        ),
      ),
    );
    expect(find.byIcon(qweatherIcon('100')!), findsOneWidget);
    expect(find.textContaining('晴'), findsNothing);
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('metadata without weather uses plain text', (tester) async {
    await tester.pumpWidget(
      wrap(DiaryFeedTile(diary: diary(), place: place())),
    );
    final metadata = tester.widget<Text>(find.textContaining(place().name));
    expect(metadata.data, endsWith(' · ${place().name}'));
    expect(metadata.textSpan, isNull);
    expect(metadata.maxLines, 1);
    expect(metadata.overflow, TextOverflow.ellipsis);
  });

  testWidgets('selection mark leaves room for the title', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(
            title: 'A long title that should leave room for the mark ' * 20,
          ),
          selecting: true,
          selected: true,
        ),
      ),
    );
    expect(find.byType(MSelectMark), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(
      t.getTopRight(find.textContaining('A long title')).dx,
      lessThan(t.getTopLeft(find.byType(MSelectMark)).dx),
    );
  });

  testWidgets('audio-only entry shows a microphone', (t) async {
    await t.pumpWidget(
      wrap(DiaryFeedTile(diary: diary(audios: const ['a.m4a']))),
    );
    expect(t.takeException(), isNull);
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
  });

  testWidgets('feed hero uses single, paired and mosaic layouts', (t) async {
    for (final count in [1, 2, 3]) {
      await t.pumpWidget(
        wrap(
          DiaryFeedTile(
            diary: diary(images: List.generate(count, (index) => '$index.jpg'))
                .copyWith(aspect: 2),
          ),
        ),
      );
      final cells = find.byType(DiaryMediaCell);
      final first = t.getRect(cells.at(0));
      expect(cells, findsNWidgets(count));
      expect(
        find.descendant(
          of: find.byType(DiaryFeedTile),
          matching: find.byType(LayoutBuilder),
        ),
        findsOneWidget,
      );
      for (var index = 0; index < count; index++) {
        final cell = cells.at(index);
        expect(
          t.widget<DiaryMediaCell>(cell).width,
          closeTo(t.getSize(cell).width, 0.01),
        );
      }
      if (count == 1) {
        expect(first.width / first.height, closeTo(2, 0.01));
      } else {
        final second = t.getRect(cells.at(1));
        expect(second.left - first.right, closeTo(3, 0.01));
        expect(first.top, second.top);
        if (count == 2) {
          expect(first.size, second.size);
          expect(first.height, closeTo((first.width * 2 + 3) * 0.55, 0.01));
        } else {
          final third = t.getRect(cells.at(2));
          expect(first.width, closeTo(second.width * 2, 0.01));
          expect(second.left, third.left);
          expect(third.top - second.bottom, closeTo(3, 0.01));
          expect(first.bottom, closeTo(third.bottom, 0.01));
        }
      }
    }
  });

  testWidgets('more than three media cells collapse into a +N overlay', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(
            images: const ['1.jpg', '2.jpg', '3.jpg', '4.jpg', '5.jpg'],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('+2'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('audio stays visible when the entry also has images', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(images: const ['1.jpg'], audios: const ['a.m4a']),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
  });

  testWidgets('the shown timestamp follows the sort key', (t) async {
    final d = diarySummaryFromDiary(
      Diary(
        id: 'x',
        title: 'T',
        content: '',
        contentText: 'body',
        time: DateTime(2026, 7, 1, 9, 15),
        lastModified: DateTime(2026, 8, 20, 21, 30),
        show: true,
        mood: null,
        imageName: const [],
        audioName: const [],
        videoName: const [],
        type: DiaryType.tiptap.value,
      ),
    );

    await t.pumpWidget(wrap(DiaryFeedTile(diary: d, sort: .timeDesc)));
    expect(find.textContaining('7/1', findRichText: true), findsOneWidget);

    await t.pumpWidget(wrap(DiaryFeedTile(diary: d, sort: .lastModifiedDesc)));
    expect(find.textContaining('8/20', findRichText: true), findsOneWidget);
  });

  testWidgets('video takes the first cell and carries a video mark', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(videos: const ['video-1.mp4'], images: const ['1.jpg']),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.byIcon(LucideIcons.video), findsOneWidget);
    expect(
      t.widget<DiaryMediaCell>(find.byType(DiaryMediaCell).first).media.isVideo,
      isTrue,
    );
  });
}
