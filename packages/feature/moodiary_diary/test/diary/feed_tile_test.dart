import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/widget/feed_tile.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

Diary diary({
  String title = 'T',
  String text = 'body',
  DiaryMood mood = .neutral,
  List<String> images = const [],
  List<String> videos = const [],
  List<String> audios = const [],
  List<String> tags = const [],
  DiaryPosition? position,
  DiaryWeather? weather,
}) => Diary(
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
  tags: tags,
  position: position,
  type: DiaryType.tiptap.value,
);

Category cat() =>
    Category(id: 'a', categoryName: 'work', lastModified: DateTime(2026));

Widget wrap(Widget child) => MuiTheme(
  data: _mui,
  child: MaterialApp(
    home: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  setUpAll(() {
    // 图片路径走 AppFiles，它读的是 late final 的应用目录；宿主测试没跑过 init。
    // 只影响拼出来的路径字符串（文件本来就不存在，走 errorBuilder）。
    try {
      PlatformService.get().applicationSupportPath = '/tmp/moodiary-test';
    } catch (_) {
      // 同一个测试进程里只能设一次，重复设置直接忽略。
    }
  });

  testWidgets('renders text-only entry inside a ListView without error', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(title: '标题在这'),
          category: cat(),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    // 标题行是 Text.rich（行首那根心情色标是 WidgetSpan），要按富文本查找。
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
            position: const DiaryPosition(
              latitude: 1,
              longitude: 2,
              name: '厦门 环岛路',
            ),
          ),
          category: cat(),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    // 元信息是单个 Text.rich：整行拼在一起，装不下时靠省略号，不会 overflow。
    final meta = t.widgetList<Text>(find.byType(Text)).firstWhere((w) {
      final s = w.textSpan?.toPlainText() ?? '';
      return s.contains('26°');
    });
    final plain = meta.textSpan!.toPlainText();
    expect(plain, contains('work'));
    expect(plain, contains('厦门 环岛路'));
    expect(meta.maxLines, 1);
    expect(meta.overflow, TextOverflow.ellipsis);
  });

  testWidgets('category label follows showCategoryLabel', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(),
          category: cat(),
          showCategoryLabel: false,
        ),
      ),
    );
    expect(find.textContaining('work'), findsNothing);
  });

  testWidgets('tags show as chips and cap at two', (t) async {
    await t.pumpWidget(
      wrap(DiaryFeedTile(diary: diary(tags: const ['a', 'b', 'c']))),
    );
    expect(find.text('#a'), findsOneWidget);
    expect(find.text('#b'), findsOneWidget);
    expect(find.text('#c'), findsNothing);
  });

  testWidgets('selection mark replaces the tags while selecting', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(tags: const ['a']),
          selecting: true,
          selected: true,
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    expect(find.text('#a'), findsNothing);
  });

  testWidgets('audio-only entry shows the waveform bar', (t) async {
    await t.pumpWidget(
      wrap(DiaryFeedTile(diary: diary(audios: const ['a.m4a']))),
    );
    expect(t.takeException(), isNull);
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
  });

  testWidgets(
    'a single image goes to the side thumbnail, not a full-width row',
    (t) async {
      await t.pumpWidget(
        wrap(DiaryFeedTile(diary: diary(images: const ['1.jpg']))),
      );
      expect(t.takeException(), isNull);
      // 右侧缩略图固定 96×72 —— 单图不占整行正是密度的来源。
      final box = t
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((w) => w.width == 96 && w.height == 72);
      expect(box, isNotEmpty);
    },
  );

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

  testWidgets('long tags never overflow the meta line', (t) async {
    // 标签名输入框没有长度限制，长标签是用户随手能造出来的数据。
    // 标签块是 Row 里的非 flex 子节点，不封顶的话会把整行撑爆。
    // 视口必须**真的**收窄（MediaQuery 的 size 不改变布局约束）。
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const long = '夏天的第一杯冰美式与午后的碎碎念';
    for (final images in [
      const <String>[],
      const ['1.jpg'],
      const ['1.jpg', '2.jpg', '3.jpg'],
    ]) {
      await t.pumpWidget(
        wrap(
          DiaryFeedTile(
            diary: diary(
              images: images,
              tags: const [long, long],
              weather: const DiaryWeather(icon: '100', temp: '26', text: '晴'),
              position: const DiaryPosition(
                latitude: 1,
                longitude: 2,
                name: '厦门 环岛路',
              ),
            ),
            category: cat(),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: '图片数=${images.length}');
    }
  });

  testWidgets('long tags survive a larger text scale too', (t) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: .linear(1.3)),
        child: wrap(
          DiaryFeedTile(
            diary: diary(
              images: const ['1.jpg'],
              tags: const ['一个相当长的标签名字', '另一个也不短的标签'],
            ),
            category: cat(),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('audio stays visible when the entry also has images', (t) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(images: const ['1.jpg'], audios: const ['a.m4a']),
        ),
      ),
    );
    // 有图时波形条让位给图片，语音只剩元信息行里的标记 —— 不能连它也没有。
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
  });

  testWidgets('the shown timestamp follows the sort key', (t) async {
    final d = Diary(
      id: 'x',
      title: 'T',
      content: '',
      contentText: 'body',
      time: DateTime(2026, 7, 1, 9, 15),
      lastModified: DateTime(2026, 8, 20, 21, 30),
      show: true,
      mood: .neutral,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: DiaryType.tiptap.value,
    );

    await t.pumpWidget(wrap(DiaryFeedTile(diary: d, sort: .timeDesc)));
    expect(find.textContaining('7/1', findRichText: true), findsOneWidget);

    await t.pumpWidget(wrap(DiaryFeedTile(diary: d, sort: .lastModifiedDesc)));
    expect(find.textContaining('8/20', findRichText: true), findsOneWidget);
  });

  testWidgets('video takes the first cell and is marked as playable', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(
        DiaryFeedTile(
          diary: diary(videos: const ['video-1.mp4'], images: const ['1.jpg']),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    // 时长没有存进模型，所以只标「这是视频」。
    expect(find.byIcon(LucideIcons.circlePlay), findsOneWidget);
  });
}
