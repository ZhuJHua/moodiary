import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/word_cloud_settings.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_canvas.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_dictionary_page.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_page.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_range_page.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

/// 页面级测试：真的建库、真的写日记、真的走 jieba 分词，然后看渲染结果。
void main() {
  late MoodiaryDatabase db;
  late MemoryKVStorage kv;

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    kv = MemoryKVStorage();
    getIt.pushNewScope(
      init: (gi) {
        gi.registerSingleton<IKVStorage>(kv);
        gi.registerSingleton<MoodiaryDatabase>(db);
        gi.registerSingleton<DiaryRepository>(DiaryRepository(db));
        gi.registerSingleton<WordCloudRepository>(WordCloudRepository(db));
      },
    );
  });

  tearDown(() async {
    getIt.popScope();
    await db.close();
  });

  Future<void> addDiary(String text, DateTime time) => db
      .into(db.diaries)
      .insert(
        DiariesCompanion.insert(
          id: 'd-${time.microsecondsSinceEpoch}',
          title: '',
          content: '',
          contentText: text,
          time: dbTime(time),
          lastModified: dbTime(time),
          show: 1,
          type: 'tiptap',
        ),
      );

  /// provider 链是异步的，用几帧把它推完；最后等播放动画自己停下。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('区间内有日记就出词云画布', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    expect(find.byType(WordCloudCanvas), findsOneWidget);
    expect(find.text('词云'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('区间内没有日记 → 空态', (tester) async {
    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    expect(find.byType(WordCloudCanvas), findsNothing);
    expect(find.text('这段时间还没有可以成词的记录'), findsOneWidget);
  });

  testWidgets('屏蔽掉唯一的词之后词云变空', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果', DateTime(now.year, now.month, 1, 12));
    MoodiaryKVs.wordCloudBlockedWords.set(const ['苹果']);

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    expect(find.byType(WordCloudCanvas), findsNothing);
    expect(find.text('这段时间还没有可以成词的记录'), findsOneWidget);
    expect(kv.data[MoodiaryKVs.wordCloudBlockedWords.name], ['苹果']);
  });

  testWidgets('页面开着时改屏蔽词，词云自动重算', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(find.byType(WordCloudCanvas), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordCloudPage)),
    );
    container.read(wordCloudBlockedProvider.notifier).add('苹果');
    await settle(tester);

    expect(find.byType(WordCloudCanvas), findsNothing);
    expect(find.text('这段时间还没有可以成词的记录'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('暂停在末尾时改屏蔽词，画布会重绘（不只是重算）', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    await tester.pumpAndSettle(); // 播放结束，画面静止
    final before = await _digest(tester);

    ProviderScope.containerOf(tester.element(find.byType(WordCloudPage)))
        .read(wordCloudBlockedProvider.notifier)
        .add('苹果');
    await settle(tester);
    await tester.pump();
    final after = await _digest(tester);

    // 只重算不重绘的话，这两张图会一模一样
    expect(after, isNot(before));
    await tester.pumpAndSettle();
  });

  testWidgets('播放条：只有播放/暂停与快慢，速度只改节奏不改位置', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    await tester.pumpAndSettle();
    // 不自动播：停在第一段
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(find.text('1×'), findsOneWidget);

    // 快一点：位置不动，只换速度（也不开始播）
    await tester.tap(find.byTooltip('快一点'));
    await settle(tester);
    expect(find.text('1.5×'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);

    // 一路到最快就禁用；往回退到最慢也禁用
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('快一点'));
      await settle(tester);
    }
    expect(find.text('3×'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, LucideIcons.chevronRight),
          )
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('慢一点'));
      await settle(tester);
    }
    expect(find.text('0.5×'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, LucideIcons.chevronLeft),
          )
          .onPressed,
      isNull,
    );
    // 全程都没动过位置
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('这一段/累计开关在底部控制条里，切换后画布还在', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(find.text('这一段'), findsOneWidget);
    expect(find.text('累计'), findsOneWidget);

    await tester.tap(find.text('累计'));
    await settle(tester);
    expect(find.byType(WordCloudCanvas), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('范围选择器：点月份选一段，最早/最新一键贴边', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, 2, 10, 12));
    await addDiary('西瓜', DateTime(now.year, 5, 20, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudRangePage(), wrapScaffold: false),
    );
    await settle(tester);

    // 年视图：12 个月份卡，2 月与 5 月有篇数
    expect(
      find.text(TimeFormat.monthAbbr(DateTime(now.year, 2))),
      findsWidgets,
    );
    expect(find.textContaining('1 篇'), findsWidgets);
    expect(find.text('开始日期'), findsOneWidget);
    expect(find.text('结束日期'), findsOneWidget);

    // 点月份：第一下是开始，第二下是结束
    await tester.tap(find.text(TimeFormat.monthAbbr(DateTime(now.year, 2))));
    await settle(tester);
    expect(find.textContaining('已选开始'), findsOneWidget);
    await tester.tap(find.text(TimeFormat.monthAbbr(DateTime(now.year, 5))));
    await settle(tester);
    final start = tester
        .widget<OutlinedButton>(
          find.ancestor(
            of: find.text(TimeFormat.anchorDate(DateTime(now.year, 2, 1))),
            matching: find.byType(OutlinedButton),
          ),
        )
        .onPressed;
    expect(start, isNotNull);

    // 最早/最新：一键把两端贴到语料边界
    await tester.tap(find.text('从最早一篇开始'));
    await settle(tester);
    await tester.tap(find.text('到最新一篇为止'));
    await settle(tester);
    expect(
      find.text(TimeFormat.anchorDate(DateTime(now.year, 2, 10))),
      findsOneWidget,
    );
    expect(
      find.text(TimeFormat.anchorDate(DateTime(now.year, 5, 20))),
      findsOneWidget,
    );
  });

  testWidgets('窄屏（360dp）下三个区域不溢出', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    // 底栏：播放/暂停 + 快慢 + 倍速 + 本段/累计 都在一行里
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
    expect(find.text('这一段'), findsOneWidget);
    expect(find.text('累计'), findsOneWidget);
    // RenderFlex 溢出在测试里会直接抛异常，能走到这里就说明没溢出
    expect(find.byType(WordCloudCanvas), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('词典页：自定义词与屏蔽词各自写入，删除后移走', (tester) async {
    await tester.pumpWidget(
      muiTestApp(const WordCloudDictionaryPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(find.textContaining('还没有添加'), findsWidgets);

    // 两个输入框：第一个是自定义词，第二个是屏蔽词
    final fields = find.byType(MField);
    await tester.enterText(fields.at(0), '存在性');
    await tester.pump();
    await tester.tap(find.byTooltip('保留'));
    await settle(tester);
    expect(kv.data[MoodiaryKVs.wordCloudLexicon.name], ['存在性']);

    await tester.enterText(fields.at(1), '苹果');
    await tester.pump();
    await tester.tap(find.byTooltip('添加'));
    await settle(tester);
    expect(kv.data[MoodiaryKVs.wordCloudBlockedWords.name], ['苹果']);

    // 删掉屏蔽词那一枚（按 chip 文本定位，别误删自定义词）
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, '苹果'),
        matching: find.byIcon(LucideIcons.x),
      ),
    );
    await settle(tester);
    expect(kv.data[MoodiaryKVs.wordCloudBlockedWords.name], isEmpty);
    expect(kv.data[MoodiaryKVs.wordCloudLexicon.name], ['存在性']);
  });

  testWidgets('词典页：隐藏单个字开关落 KV', (tester) async {
    await tester.pumpWidget(
      muiTestApp(const WordCloudDictionaryPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(kv.data[MoodiaryKVs.wordCloudHideSingleChars.name] ?? false, false);

    await tester.tap(find.text('隐藏单个字'));
    await settle(tester);
    expect(kv.data[MoodiaryKVs.wordCloudHideSingleChars.name], true);
  });

  testWidgets('时间范围栏显眼地写着实际起止日期与派生段数', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    // 本年预设：写实际日期（用同一个格式化器算期望，避免跟语言绑定）；
    // 只写过一篇，所以时间轴上只有那一张，其余 11 段空白被跳过
    final title =
        '${TimeFormat.anchorDate(DateTime(now.year, 1, 1))} – '
        '${TimeFormat.anchorDate(DateTime(now.year, 12, 31))}';
    expect(find.text(title), findsOneWidget);
    expect(find.textContaining('共 1 段 · 每段 1 月'), findsOneWidget);
    expect(find.textContaining('跳过 11 个空白时段'), findsOneWidget);
    expect(find.textContaining('第 1/'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('时间范围面板：范围 + 每段覆盖多久（周/月/季度/年）', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(find.textContaining('共 1 段 · 每段 1 月'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.chevronDown).first);
    await tester.pumpAndSettle();
    expect(find.text('时间范围'), findsWidgets);
    expect(find.text('每段覆盖多久'), findsOneWidget);
    // 四个单位，没有「天」
    expect(find.text('周'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('季度'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('天'), findsNothing);

    // 换成按季度：同一段区间变成按季度切
    await tester.tap(find.text('季度'));
    await settle(tester);
    expect(find.textContaining('每段 1 季度'), findsWidgets);
    expect(find.byType(WordCloudCanvas), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('控制条的「第 i/N 段」：N 是段数，不是段间隔数', (tester) async {
    final now = DateTime.now();
    // 三个不同的月份都有日记 → 按年（默认按月）就是 3 段
    await addDiary('苹果', DateTime(now.year, 3, 10, 12));
    await addDiary('苹果', DateTime(now.year, 6, 10, 12));
    await addDiary('苹果', DateTime(now.year, 9, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    expect(find.textContaining('共 3 段'), findsOneWidget);
    // 3 段就写 3（以前这里写的是段间隔数 2，会出现「第 3/2 段」）
    expect(find.textContaining('第 1/3 段'), findsOneWidget);
    expect(find.textContaining('/2 段'), findsNothing);

    // 点播放，播到结尾也不会超过总数
    await tester.tap(find.byTooltip('播放'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 3/3 段'), findsOneWidget);
  });

  testWidgets('只有点播放才动：进页面、换范围、改词表都不自动播', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果香蕉', DateTime(now.year, now.month, 1, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(find.byTooltip('播放'), findsOneWidget);

    // 换「每段覆盖多久」：不播，而且停在同一个时间点上
    await tester.tap(find.byIcon(LucideIcons.chevronDown).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('季度'));
    await settle(tester);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);

    // 改词表（数据重算）：还是不播
    ProviderScope.containerOf(tester.element(find.byType(WordCloudPage)))
        .read(wordCloudBlockedProvider.notifier)
        .add('香蕉');
    await settle(tester);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('播放中途暂停：落到最近的一段，不是停在一半', (tester) async {
    final now = DateTime.now();
    // 按月切，本年里 4 个月有日记 → 4 段，段间隔 3
    await addDiary('苹果', DateTime(now.year, 3, 10, 12));
    await addDiary('苹果', DateTime(now.year, 6, 10, 12));
    await addDiary('苹果', DateTime(now.year, 9, 10, 12));
    await addDiary('苹果', DateTime(now.year, 11, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    await tester.tap(find.byTooltip('播放'));
    // 播到大概第 1~2 段之间（总时长 3 × 900ms）
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byTooltip('暂停'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await settle(tester);

    // 暂停后一定落在整数段上
    final value = tester.widget<Slider>(find.byType(Slider)).value;
    final position = value * 3;
    expect(position, closeTo(position.roundToDouble(), 1e-6));
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.textContaining('/4 段'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('滑动切段：左滑/下滑上一段，右滑/上滑下一段，且中止动画', (tester) async {
    final now = DateTime.now();
    await addDiary('苹果', DateTime(now.year, 3, 10, 12));
    await addDiary('苹果', DateTime(now.year, 6, 10, 12));
    await addDiary('苹果', DateTime(now.year, 9, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    expect(find.textContaining('第 1/3 段'), findsOneWidget);

    // 点在画布外面一点点的位置滑：起手不能落在单词上（会开词详情）
    final canvas = tester.getRect(find.byType(WordCloudCanvas));
    final start = Offset(canvas.center.dx, canvas.bottom - 12);

    // 右滑 = 下一段
    await tester.dragFrom(start, const Offset(120, 0));
    await settle(tester);
    expect(find.textContaining('第 2/3 段'), findsOneWidget);

    // 上滑 = 下一段
    await tester.dragFrom(start, const Offset(0, -120));
    await settle(tester);
    expect(find.textContaining('第 3/3 段'), findsOneWidget);

    // 下滑 = 上一段
    await tester.dragFrom(start, const Offset(0, 120));
    await settle(tester);
    expect(find.textContaining('第 2/3 段'), findsOneWidget);

    // 左滑 = 上一段
    await tester.dragFrom(start, const Offset(-120, 0));
    await settle(tester);
    expect(find.textContaining('第 1/3 段'), findsOneWidget);

    // 已经到头了：再往回滑也不越界
    await tester.dragFrom(start, const Offset(-120, 0));
    await settle(tester);
    expect(find.textContaining('第 1/3 段'), findsOneWidget);

    // 播放中滑动 → 动画中止
    await tester.tap(find.byTooltip('播放'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.dragFrom(start, const Offset(120, 0));
    await settle(tester);
    expect(find.byTooltip('播放'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('空白时段完全跳过：只在一段时间里写过，就只出那几段', (tester) async {
    final now = DateTime.now();
    // 本年只在 3 月写过一篇；按月切，其余 11 个月都没有词
    await addDiary('苹果香蕉', DateTime(now.year, 3, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    // 一段 + 跳过 11 个空白时段
    expect(find.textContaining('共 1 段'), findsOneWidget);
    expect(find.textContaining('跳过 11 个空白时段'), findsOneWidget);
    expect(find.textContaining('第 1/1 段'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('调整后保留当前时间点：换单位不跳回开头', (tester) async {
    final now = DateTime.now();
    // 按月切：3/6/9/11 月各一段
    await addDiary('苹果', DateTime(now.year, 3, 10, 12));
    await addDiary('苹果', DateTime(now.year, 6, 10, 12));
    await addDiary('苹果', DateTime(now.year, 9, 10, 12));
    await addDiary('苹果', DateTime(now.year, 11, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);

    // 播到末尾：停在 11 月那一段
    await tester.tap(find.byTooltip('播放'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 4/4 段'), findsOneWidget);
    expect(
      find.textContaining(TimeFormat.anchorDate(DateTime(now.year, 11, 1))),
      findsOneWidget,
    );

    // 换成按季度：3/6/9/11 月分别落在 Q1/Q2/Q3/Q4，还是 4 段；
    // 应该停在包含 11 月的那一段（Q4，第 4/4 段），而不是跳回开头
    await tester.tap(find.byIcon(LucideIcons.chevronDown).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('季度'));
    await settle(tester);
    await tester.pump();

    expect(find.textContaining('共 4 段 · 每段 1 季度'), findsOneWidget);
    expect(find.textContaining('第 4/4 段'), findsOneWidget);
    expect(
      find.textContaining(TimeFormat.anchorDate(DateTime(now.year, 10, 1))),
      findsOneWidget,
    );
    expect(find.byTooltip('播放'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('拖/拍进度条后停在分割点上，不停在两段中间', (tester) async {
    final now = DateTime.now();
    // 四个不同月份有日记 → 4 段，段间隔 3
    await addDiary('苹果', DateTime(now.year, 3, 10, 12));
    await addDiary('苹果', DateTime(now.year, 6, 10, 12));
    await addDiary('苹果', DateTime(now.year, 9, 10, 12));
    await addDiary('苹果', DateTime(now.year, 11, 10, 12));

    await tester.pumpWidget(
      muiTestApp(const WordCloudPage(), wrapScaffold: false),
    );
    await settle(tester);
    await tester.pumpAndSettle(); // 本来就没在播，画面静止
    expect(find.textContaining('共 4 段'), findsOneWidget);

    // 在进度条中间偏左的位置按下再松开（tap 会走 changeStart/changeEnd）
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(
      Offset(slider.left + slider.width * 0.42, slider.center.dy),
    );
    await settle(tester);

    final value = tester.widget<Slider>(find.byType(Slider)).value;
    final position = value * 3; // 段间隔数 = 4 - 1
    expect(position, closeTo(position.roundToDouble(), 1e-6));
    await tester.pumpAndSettle();
  });
}

/// 把词云画布的像素摘要出来：只重算不重绘时两张图完全相同。
Future<int> _digest(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byType(WordCloudCanvas),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ImageByteFormat.rawRgba),
  );
  image.dispose();
  var hash = 17;
  for (final byte in bytes!.buffer.asUint8List()) {
    hash = (hash * 31 + byte) & 0x3fffffff;
  }
  return hash;
}
