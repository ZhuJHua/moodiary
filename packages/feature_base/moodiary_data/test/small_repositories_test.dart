import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => db.close());

  group('CategoryRepository', () {
    test('增删查 + 墓碑 + 复活闸门', () async {
      final repo = CategoryRepository(db);
      final tombs = TombstoneRepository(db);
      final c = Category.create(categoryName: '生活');
      await repo.insertACategory(c);
      expect((await repo.getAllCategories()).single.categoryName, '生活');
      expect((await repo.getCategoryById(c.id))?.id, c.id);

      expect(await repo.deleteACategory(c.id), isTrue);
      expect(await repo.getAllCategories(), isEmpty);
      expect(await tombs.getByKey(SyncTombstone.categoryKey(c.id)), isNotNull);
      await repo.insertACategory(c);
      expect(await tombs.getByKey(SyncTombstone.categoryKey(c.id)), isNull);
    });

    test('分类下有日记时拒绝删除', () async {
      final repo = CategoryRepository(db);
      final c = Category.create(categoryName: '生活');
      await repo.insertACategory(c);
      await db
          .into(db.diaries)
          .insert(
            DiariesCompanion.insert(
              id: 'd1',
              categoryId: Value(c.id),
              title: '',
              content: '',
              contentText: '',
              time: 0,
              lastModified: 0,
              show: 1,
              type: 'tiptap',
            ),
          );
      expect(await repo.deleteACategory(c.id), isFalse);
      expect(await repo.getAllCategories(), hasLength(1));
    });
  });

  group('TombstoneRepository', () {
    test('putAll / deleteByKeys / purgeExpired', () async {
      final repo = TombstoneRepository(db);
      final now = DateTime.utc(2026, 6, 1);
      await repo.putAll([
        SyncTombstone.forDiary(
          'old',
          at: now.subtract(const Duration(days: 91)),
        ),
        SyncTombstone.forDiary('fresh', at: now),
        SyncTombstone(
          key: SyncTombstone.categoryKey('c'),
          timeMs: now.millisecondsSinceEpoch,
          pushedBackends: const ['backend-a'],
        ),
      ]);
      expect(await repo.getAll(), hasLength(3));
      final pushed = (await repo.getByKey(SyncTombstone.categoryKey('c')))!;
      expect(pushed.pushedBackends, ['backend-a']);
      expect(pushed.kind, TombstoneKind.category);
      expect(pushed.entityId, 'c');

      final purged = await repo.purgeExpired(now: now);
      expect(purged, 1);
      expect(await repo.getByKey(SyncTombstone.diaryKey('old')), isNull);

      await repo.deleteByKeys([SyncTombstone.diaryKey('fresh')]);
      expect(await repo.getAll(), hasLength(1));
    });
  });

  group('FontRepository', () {
    test('按 family upsert / 查 / 删，字重轴 JSON 往返', () async {
      final repo = FontRepository(db);
      const font = Font(
        fontFileName: 'LXGW.ttf',
        fontWghtAxisMap: {'wght': 400},
      );
      await repo.insertFont(font);
      final got = (await repo.getFontByFontFamily('LXGW'))!;
      expect(got.fontFileName, 'LXGW.ttf');
      expect(got.fontWghtAxisMap, {'wght': 400});
      expect(got.fontType, '.ttf');

      await repo.deleteFontByFamily('LXGW');
      expect(await repo.getAllFonts(), isEmpty);
    });
  });

  group('WordCloudRepository', () {
    Future<void> addDiary(
      String id,
      String text,
      DateTime time, {
      String title = '',
      bool show = true,
    }) => db
        .into(db.diaries)
        .insert(
          DiariesCompanion.insert(
            id: id,
            title: title,
            content: '',
            contentText: text,
            time: dbTime(time),
            lastModified: dbTime(time),
            show: show ? 1 : 0,
            type: 'tiptap',
          ),
        );

    // 三篇分布在三个月：苹果 2+1、西瓜 1+2、香蕉 1+1。
    Future<void> seedThreeMonths() async {
      await addDiary('d1', '苹果苹果香蕉', DateTime(2026, 1, 5));
      await addDiary('d2', '苹果西瓜', DateTime(2026, 2, 10));
      await addDiary('d3', '香蕉西瓜西瓜', DateTime(2026, 3, 20));
    }

    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 4, 1);

    WordCloudWindowPlan planOf({
      WordCloudUnit unit = .month,
      int length = 1,
      int step = 1,
      DateTime? t0,
      DateTime? t1,
    }) => WordCloudWindowPlan.build(
      unit: unit,
      length: length,
      step: step,
      t0: t0 ?? start,
      t1: t1 ?? end,
    );

    test('按月分段统计词频，顺序确定', () async {
      await seedThreeMonths();
      final data = await WordCloudRepository(db).build(plan: planOf());

      expect(data.windowCount, 3);
      expect(data.diaryCount, 3);
      expect(data.terms.map((t) => t.word), ['苹果', '西瓜', '香蕉']);
      expect(data.terms[0].total, 3);
      expect(data.terms[0].counts, [2, 1, 0]);
      expect(data.terms[1].counts, [0, 1, 2]);
      expect(data.terms[2].counts, [1, 0, 1]);
      expect(data.terms[2].cumulativeAt(2), 2);
      expect(data.windowAt(1)!.start, DateTime(2026, 2, 1));
      // 三段都有词：播放窗口覆盖全部
      expect(data.activeFirst, 0);
      expect(data.activeLast, 2);
      expect(data.segmentCount, 2);
      expect(data.windowPositionAt(0), 0);
      expect(data.windowPositionAt(1), 2);
      expect(data.windowPositionAt(0.5), 1);
    });

    test('空白时段不进时间轴', () async {
      // 一月、二月空着，只有三月有日记：时间轴上只留三月那一张
      await addDiary('d1', '苹果香蕉', DateTime(2026, 3, 20));
      final repo = WordCloudRepository(db);
      // 计划里仍然是三段（窗口按区间切）
      expect(planOf().windowCount, 3);
      final data = await repo.build(plan: planOf());
      expect(data.windowCount, 1);
      expect(data.windows.single.start, DateTime(2026, 3, 1));
      expect(data.activeFirst, 0);
      expect(data.activeLast, 0);
      expect(data.segmentCount, 1);
      expect(data.windowPositionAt(0), 0);
      expect(data.windowPositionAt(1), 0);
    });

    test('步长小于窗口长度：滑动窗口，一篇日记进多张，空白仍被跳过', () async {
      // 3 月 15 日的日记会落进 1 月、2 月、3 月三个窗口；4/5 月两张是空的
      await addDiary('d1', '苹果', DateTime(2026, 3, 15));
      final data = await WordCloudRepository(db)
          .build(plan: planOf(length: 3, step: 1, t1: DateTime(2026, 6, 1)));
      expect(data.windowCount, 3);
      expect(data.terms.single.word, '苹果');
      expect(data.terms.single.counts, [1, 1, 1]);
      // total 仍然是「语料里出现 1 次」，不因窗口重叠而翻倍
      expect(data.terms.single.total, 1);
      expect(data.tokenCount, 1);
    });

    test('limit 截断取词频最高的若干个', () async {
      await seedThreeMonths();
      final data = await WordCloudRepository(db)
          .build(plan: planOf(), limit: 1);
      expect(data.terms.map((t) => t.word), ['苹果']);
      // tokenCount 统计的是全部候选词，不受 limit 影响
      expect(data.tokenCount, 8);
    });

    test('屏蔽词既不统计也不占名额', () async {
      await seedThreeMonths();
      final data = await WordCloudRepository(db)
          .build(plan: planOf(), blocked: const {'苹果'}, limit: 2);
      expect(data.terms.map((t) => t.word), ['西瓜', '香蕉']);
    });

    test('标题按权重计入', () async {
      await addDiary('d1', '苹果香蕉', DateTime(2026, 1, 5), title: '香蕉');
      int totalOf(WordCloudData data, String word) =>
          data.terms.firstWhere((t) => t.word == word).total;
      final once = await WordCloudRepository(db).build(plan: planOf());
      expect(totalOf(once, '香蕉'), 2);
      final heavy = await WordCloudRepository(db)
          .build(plan: planOf(), titleWeight: 3);
      expect(totalOf(heavy, '香蕉'), 4);
      final noTitle = await WordCloudRepository(db)
          .build(plan: planOf(), titleWeight: 0);
      expect(totalOf(noTitle, '香蕉'), 1);
    });

    test('标点、停用词与超长串不进云', () async {
      await addDiary('d1', '苹果，。！？—— ${'a' * 30}', DateTime(2026, 1, 5));
      final data = await WordCloudRepository(db).build(plan: planOf());
      expect(data.terms.map((t) => t.word), ['苹果']);
    });

    test('自定义词典把错切的长词切回来（真机反馈的原句）', () async {
      await addDiary('d1', '存在性需求', DateTime(2026, 1, 5));
      final repo = WordCloudRepository(db);

      // 现状：上游词典里有「性需求 3」而没有「存在性」，于是被切成两半
      final before = await repo.build(plan: planOf());
      expect(before.terms.map((t) => t.word), ['存在', '性需求']);

      // 词典里加上正确的那半，最长匹配优先 → 切回「存在性 / 需求」
      final after = await repo.build(
        plan: planOf(),
        lexicon: WordCloudLexicon(const ['存在性']),
      );
      expect(after.terms.map((t) => t.word), ['存在性', '需求']);
    });

    test('词典也能拆开错粘的长词', () async {
      await addDiary('d1', '今天天气很好', DateTime(2026, 1, 5));
      final repo = WordCloudRepository(db);
      // 「好」已被内置停用词表吃掉，剩下的就是那个粘住的长词
      expect((await repo.build(plan: planOf())).terms.map((t) => t.word), [
        '今天天气',
      ]);
      final fixed = await repo.build(
        plan: planOf(),
        lexicon: WordCloudLexicon(const ['今天', '天气']),
      );
      expect(fixed.terms.map((t) => t.word), ['今天', '天气']);
    });

    test('优先级：屏蔽词 > 自定义词典 > 内置停用词表', () async {
      // 「事」在内置停用词表里，单独成词
      await addDiary('d1', '事', DateTime(2026, 1, 5));
      final repo = WordCloudRepository(db);

      expect((await repo.build(plan: planOf())).terms, isEmpty);
      // 词典是保留名单：加进来就能出现
      final kept = await repo.build(
        plan: planOf(),
        lexicon: WordCloudLexicon(const ['事']),
      );
      expect(kept.terms.map((t) => t.word), ['事']);
      // 屏蔽词优先于词典
      final blocked = await repo.build(
        plan: planOf(),
        lexicon: WordCloudLexicon(const ['事']),
        blocked: const {'事'},
      );
      expect(blocked.terms, isEmpty);
    });

    test('隐藏单个字：实义单字一起去掉', () async {
      await addDiary('d1', '苹果猫', DateTime(2026, 1, 5));
      final repo = WordCloudRepository(db);
      final without = (await repo.build(plan: planOf())).terms
          .map((t) => t.word)
          .toList();
      expect(without, contains('猫'));
      expect(without, contains('苹果'));

      expect(
        (await repo.build(
          plan: planOf(),
          hideSingleChars: true,
        )).terms.map((t) => t.word),
        ['苹果'],
      );
      // 词典可以把它捞回来
      expect(
        (await repo.build(
          plan: planOf(),
          hideSingleChars: true,
          lexicon: WordCloudLexicon(const ['猫']),
        )).terms.map((t) => t.word),
        contains('猫'),
      );
    });

    test('回收站与空区间', () async {
      await addDiary('d1', '苹果', DateTime(2026, 1, 5), show: false);
      final repo = WordCloudRepository(db);
      final hidden = await repo.build(plan: planOf(unit: .day));
      expect(hidden.isEmpty, isTrue);
      expect(hidden.diaryCount, 0);
      // 计划里是 90 天，但一张都没留下（没有词）
      expect(planOf(unit: .day).windowCount, 90);
      expect(hidden.windowCount, 0);

      final none = await repo.build(
        plan: planOf(t0: DateTime(2015, 1, 1), t1: DateTime(2015, 2, 1)),
      );
      expect(none.isEmpty, isTrue);
      expect(none.windowCount, 0);
      expect(none.start, DateTime(2015, 1, 1));
    });

    test('空区间（end 早于 start）不炸', () async {
      final data = await WordCloudRepository(db).build(
        plan: planOf(t0: end, t1: start),
      );
      expect(data.isEmpty, isTrue);
      expect(data.windowCount, 0);
    });
  });

  group('wordCloudText', () {
    test('把 jieba_query(text, 0) 的输出拆回词表', () {
      expect(jiebaMatchExpressionToWords(''), isEmpty);
      expect(jiebaMatchExpressionToWords('hello*'), ['hello']);
      // 数字串是引号里再加星号：先摘星号，再去引号
      expect(jiebaMatchExpressionToWords('"2024"*'), ['2024']);
      expect(jiebaMatchExpressionToWords('"今天天气" AND "很"'), ['今天天气', '很']);
      // 正文里的英文引号被复制成两对
      expect(jiebaMatchExpressionToWords('""""'), ['"']);
      expect(jiebaMatchExpressionToWords('"a" AND hello* AND "2024"*'), [
        'a',
        'hello',
        '2024',
      ]);
    });

    test('候选词与停用词', () {
      expect(isWordCloudWord('苹果'), isTrue);
      expect(isWordCloudWord('2024'), isTrue);
      expect(isWordCloudWord('，'), isFalse);
      expect(isWordCloudWord('——'), isFalse);
      expect(isWordCloudWord('a' * 30), isFalse);

      expect(normalizeWordCloudWord(' Hello '), 'hello');
      expect(keepWordCloudWord('的', blocked: const {}), isFalse);
      expect(keepWordCloudWord('the', blocked: const {}), isFalse);
      expect(keepWordCloudWord('苹果', blocked: const {'苹果'}), isFalse);
      expect(keepWordCloudWord('苹果', blocked: const {}), isTrue);
      expect(keepWordCloudWord('', blocked: const {}), isFalse);
      // 单字规则只砍单字，且词典豁免优先
      expect(
        keepWordCloudWord('雨', blocked: const {}, hideSingleChars: true),
        isFalse,
      );
      expect(
        keepWordCloudWord(
          '雨',
          blocked: const {},
          keep: const {'雨'},
          hideSingleChars: true,
        ),
        isTrue,
      );
      // 标点连词典也救不了
      expect(
        keepWordCloudWord('，', blocked: const {}, keep: const {'，'}),
        isFalse,
      );
    });
  });

  group('WordCloudLexicon', () {
    test('空词典原样返回', () {
      final lexicon = WordCloudLexicon.empty;
      expect(lexicon.isEmpty, isTrue);
      const tokens = ['存在', '性需求'];
      expect(identical(lexicon.resegment(tokens), tokens), isTrue);
    });

    test('跨 token 合并 + 尾部截断（真机反馈的「存在性需求」）', () {
      final lexicon = WordCloudLexicon(const ['存在性']);
      expect(lexicon.resegment(const ['存在', '性需求']), ['存在性', '需求']);
    });

    test('单个 token 内部也能拆', () {
      final lexicon = WordCloudLexicon(const ['今天', '天气']);
      expect(lexicon.resegment(const ['今天天气', '很']), ['今天', '天气', '很']);
    });

    test('只动全是汉字的连续片段', () {
      final lexicon = WordCloudLexicon(const ['苹果']);
      expect(lexicon.resegment(const ['hello', '苹果', '2024']), [
        'hello',
        '苹果',
        '2024',
      ]);
      expect(lexicon.resegment(const ['，', '苹果']), ['，', '苹果']);
    });

    test('幂等：重切结果再切一次不变', () {
      final lexicon = WordCloudLexicon(const ['存在性', '需求']);
      final once = lexicon.resegment(const ['存在', '性需求']);
      expect(lexicon.resegment(once), once);
    });

    test('单字词条不参与重切，只当保留名单', () {
      final lexicon = WordCloudLexicon(const ['性']);
      expect(lexicon.resegment(const ['存在', '性需求']), ['存在', '性需求']);
      expect(lexicon.words.contains('性'), isTrue);
      expect(lexicon.resegmentableCount, 0);
    });
  });

  group('WordCloudWindowPlan', () {
    test('按跨度推荐单位：只在周/月/季度/年里选', () {
      expect(
        WordCloudUnit.forSpan(const Duration(days: 7)),
        WordCloudUnit.week,
      );
      expect(
        WordCloudUnit.forSpan(const Duration(days: 100)),
        WordCloudUnit.week,
      );
      expect(
        WordCloudUnit.forSpan(const Duration(days: 365)),
        WordCloudUnit.month,
      );
      expect(
        WordCloudUnit.forSpan(const Duration(days: 1000)),
        WordCloudUnit.quarter,
      );
      expect(
        WordCloudUnit.forSpan(const Duration(days: 3000)),
        WordCloudUnit.year,
      );
      // 页面上能选的四个单位，和推荐值一致（不含天）
      expect(wordCloudLengthUnits, [
        WordCloudUnit.week,
        WordCloudUnit.month,
        WordCloudUnit.quarter,
        WordCloudUnit.year,
      ]);
    });

    test('季度：对齐到自然季度首日', () {
      final plan = WordCloudWindowPlan.build(
        unit: WordCloudUnit.quarter,
        length: 1,
        step: 1,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2027, 1, 1),
      );
      expect(plan.windowCount, 4);
      expect(plan.windows[0].start, DateTime(2026, 1, 1));
      expect(plan.windows[0].endExclusive, DateTime(2026, 4, 1));
      expect(plan.windows[1].start, DateTime(2026, 4, 1));
      expect(plan.windows[2].start, DateTime(2026, 7, 1));
      expect(plan.windows[3].start, DateTime(2026, 10, 1));
      expect(plan.windows[3].endExclusive, DateTime(2027, 1, 1));
      // floor / indexOf 与 align 对齐
      expect(
        WordCloudUnit.quarter.floor(DateTime(2026, 8, 9)),
        DateTime(2026, 7, 1),
      );
      expect(
        WordCloudUnit.quarter.indexOf(
          DateTime(2026, 8, 9),
          DateTime(2026, 1, 1),
        ),
        2,
      );
    });

    test('不重叠窗口：半开区间，边界日记只算一次', () {
      final plan = WordCloudWindowPlan.build(
        unit: WordCloudUnit.day,
        length: 1,
        step: 1,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2026, 1, 4),
      );
      expect(plan.isValid, isTrue);
      expect(plan.windowCount, 3);
      expect(plan.isSliding, isFalse);
      expect(plan.windows[0].start, DateTime(2026, 1, 1));
      expect(plan.windows[0].endExclusive, DateTime(2026, 1, 2));
      // 半开：1 月 2 日零点属于第二段，不属于第一段
      expect(plan.windows[0].contains(DateTime(2026, 1, 1, 23, 59)), isTrue);
      expect(plan.windows[0].contains(DateTime(2026, 1, 2)), isFalse);
      expect(plan.windows[1].contains(DateTime(2026, 1, 2)), isTrue);
    });

    test('自然月窗口：起点对齐到月首', () {
      final plan = WordCloudWindowPlan.build(
        unit: WordCloudUnit.month,
        length: 1,
        step: 1,
        t0: DateTime(2026, 1, 15),
        t1: DateTime(2026, 4, 1),
      );
      expect(plan.windowCount, 3);
      // 第 0 段从区间起点开始（不完整），之后是自然月
      expect(plan.windows[0].partial, isTrue);
      expect(plan.windows[0].start, DateTime(2026, 1, 15));
      expect(plan.windows[0].endExclusive, DateTime(2026, 2, 1));
      expect(plan.windows[1].partial, isFalse);
      expect(plan.windows[1].start, DateTime(2026, 2, 1));
      expect(plan.windows[2].endExclusive, DateTime(2026, 4, 1));
    });

    test('滑动窗口：W > Δ 时相邻窗口重叠', () {
      final plan = WordCloudWindowPlan.build(
        unit: WordCloudUnit.month,
        length: 3,
        step: 1,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2026, 5, 1),
      );
      expect(plan.windowCount, 4);
      expect(plan.isSliding, isTrue);
      expect(plan.overlapRatio, closeTo(2 / 3, 1e-9));
      // 3 月 15 日同时落在前三段里
      final hit = [
        for (final window in plan.windows)
          if (window.contains(DateTime(2026, 3, 15))) window.start.month,
      ];
      expect(hit, [1, 2, 3]);
    });

    test('末段被区间终点截断并标记 partial', () {
      final plan = WordCloudWindowPlan.build(
        unit: WordCloudUnit.month,
        length: 1,
        step: 1,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2026, 2, 10),
      );
      expect(plan.windowCount, 2);
      expect(plan.windows[1].endExclusive, DateTime(2026, 2, 10));
      expect(plan.windows[1].partial, isTrue);
    });

    test('校验：空区间 / 非法步长 / 非法长度 / 段数上限', () {
      final empty = WordCloudWindowPlan.build(
        unit: WordCloudUnit.day,
        length: 1,
        step: 1,
        t0: DateTime(2026, 1, 2),
        t1: DateTime(2026, 1, 1),
      );
      expect(empty.error, WordCloudPlanError.emptyRange);
      expect(empty.isValid, isFalse);

      final badStep = WordCloudWindowPlan.build(
        unit: WordCloudUnit.day,
        length: 1,
        step: 0,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2026, 1, 5),
      );
      expect(badStep.error, WordCloudPlanError.badStep);

      final badLength = WordCloudWindowPlan.build(
        unit: WordCloudUnit.day,
        length: 0,
        step: 1,
        t0: DateTime(2026, 1, 1),
        t1: DateTime(2026, 1, 5),
      );
      expect(badLength.error, WordCloudPlanError.badLength);

      // 10 年按天 = 3650 段，超上限时报错而不是静默改参数
      final tooMany = WordCloudWindowPlan.build(
        unit: WordCloudUnit.day,
        length: 1,
        step: 1,
        t0: DateTime(2016, 1, 1),
        t1: DateTime(2026, 1, 1),
      );
      expect(tooMany.error, WordCloudPlanError.tooManyWindows);
      expect(tooMany.windows, isEmpty);
    });

    test('align / floor / indexOf 互相对齐', () {
      final start = DateTime(2026, 1, 15);
      expect(WordCloudUnit.month.align(start, 0), start);
      expect(WordCloudUnit.month.align(start, 2), DateTime(2026, 3, 1));
      expect(WordCloudUnit.month.indexOf(DateTime(2026, 3, 1), start), 2);
      expect(WordCloudUnit.week.indexOf(DateTime(2026, 1, 15), start), 0);
      expect(
        WordCloudUnit.week.floor(DateTime(2026, 1, 15)),
        DateTime(2026, 1, 12),
      );
      expect(
        WordCloudUnit.month.floor(DateTime(2026, 1, 15)),
        DateTime(2026, 1, 1),
      );
      expect(
        WordCloudUnit.year.floor(DateTime(2026, 7, 4)),
        DateTime(2026, 1, 1),
      );
    });
  });
}
