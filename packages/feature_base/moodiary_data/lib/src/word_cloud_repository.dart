import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'word_cloud_lexicon.dart';
import 'word_cloud_text.dart';

/// 词云：把区间内每篇日记的正文（和标题）用 jieba 分词后，按窗口统计词频。
///
/// 纯只读派生 —— 只 `SELECT content_text`，不写库、不重建 FTS、不加表，
/// 所以没有 schema/迁移/同步/备份的牵连。
///
/// 分词路径：`jieba_query(text, 0)` 内部是 cppjieba 的 `Cut`，返回的是 MATCH
/// 表达式，Dart 侧拆回词表（[jiebaMatchExpressionToWords]），可选地用自定义
/// 词典重切（[WordCloudLexicon.resegment]）。这条查询跑在 drift 的后台
/// isolate 上，而 jieba 的词典与扩展是**进程级**原生状态，所以后台连接一样能用。
///
/// 窗口：日记按时间升序返回，窗口起点也升序，所以用两指针一次扫过 ——
/// 每篇日记只会被它真正落入的窗口计数（W > Δ 时一篇日记会进多个窗口），
/// 不需要为每个窗口重复分词。
///
/// 实测成本：一年量级（1000 篇 × ~70 字）SQL 分词 23 ms + Dart 解析归并 39 ms，
/// 首次调用多付一次 cppjieba 静态初始化（~365 ms）。所以不缓存、不入库。
@lazySingleton
class WordCloudRepository {
  WordCloudRepository(this._db);

  final MoodiaryDatabase _db;

  /// 词云上限：画布放不下更多，120 个词的观感也已经足够。
  static const int defaultLimit = 120;

  /// [plan] 里的窗口是半开区间；[blocked] 与 [lexicon] 里的词必须已经过
  /// [normalizeWordCloudWord]。
  Future<WordCloudData> build({
    required WordCloudWindowPlan plan,
    Set<String> blocked = const {},
    WordCloudLexicon? lexicon,
    bool hideSingleChars = false,
    int limit = defaultLimit,
    int titleWeight = 1,
  }) async {
    final windows = plan.windows;
    if (windows.isEmpty) {
      return WordCloudData.empty(
        unit: plan.unit,
        start: plan.t0,
        endExclusive: plan.t1,
      );
    }
    final windowCount = windows.length;

    final rows = await _db
        .customSelect(
          // 汉字按字入索引，所以这里必须借 jieba_query 的 Cut 结果当分词器；
          // 具名查询走 drift 的 sqlparser，认不出这个函数，故用 customSelect
          // （先例：DiaryRepository._matchExpression）。
          'SELECT time, '
          'jieba_query(content_text, 0) AS body, '
          'jieba_query(title, 0) AS title '
          'FROM diaries '
          'WHERE show = 1 AND time >= ? AND time < ? '
          'AND length(content_text) > 0 '
          'ORDER BY time',
          variables: [
            Variable<int>(dbTime(plan.t0)),
            Variable<int>(dbTime(plan.t1)),
          ],
        )
        .get();

    final keep = lexicon?.words ?? const <String>{};
    final totals = <String, int>{};
    final perWindow = <String, List<int>>{};
    var tokenCount = 0;

    /// 一篇日记的某个字段（正文/标题）经过词典重切与过滤后的词表。
    Iterable<String> wordsOf(String expression) sync* {
      var tokens = jiebaMatchExpressionToWords(expression);
      if (lexicon != null && !lexicon.isEmpty) {
        tokens = lexicon.resegment(tokens);
      }
      for (final raw in tokens) {
        final word = normalizeWordCloudWord(raw);
        if (keepWordCloudWord(
          word,
          blocked: blocked,
          keep: keep,
          hideSingleChars: hideSingleChars,
        )) {
          yield word;
        }
      }
    }

    // 两指针：cursor 是第一个「右端还没过去」的窗口；日记升序、窗口升序，
    // 所以 cursor 只前进。从 cursor 起，起点不晚于该时刻的窗口都包含它
    // （窗口重叠时一篇日记会进多个窗口）。
    var cursor = 0;
    final hits = <int>[];
    for (final row in rows) {
      final time = dbToTime(row.read<int>('time')).toLocal();
      while (cursor < windowCount &&
          !windows[cursor].endExclusive.isAfter(time)) {
        cursor++;
      }
      hits.clear();
      for (var k = cursor; k < windowCount; k++) {
        if (windows[k].start.isAfter(time)) break;
        hits.add(k);
      }
      if (hits.isEmpty) continue;

      // 每篇日记只解析一次：语料词频（totals，也是排序/字号基准）与各窗口
      // 词频（perWindow）从同一份结果分发。所以滑动窗口下 total 仍然等于
      // 「语料里出现多少次」，不会因为窗口重叠而翻倍。
      final body = row.read<String?>('body') ?? '';
      final title = row.read<String?>('title') ?? '';
      for (final (expression, weight) in [
        (body, 1),
        if (title.isNotEmpty && titleWeight > 0) (title, titleWeight),
      ]) {
        for (final word in wordsOf(expression)) {
          totals[word] = (totals[word] ?? 0) + weight;
          final counts = perWindow[word] ??= List<int>.filled(windowCount, 0);
          for (final k in hits) {
            counts[k] += weight;
          }
          tokenCount += weight;
        }
      }
    }

    // 词频降序、同频按词升序：顺序确定 → 布局确定（重开页面不会重排）。
    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final byTotal = b.value.compareTo(a.value);
        return byTotal != 0 ? byTotal : a.key.compareTo(b.key);
      });
    final selected = (limit > 0 ? sorted.take(limit) : sorted).toList();

    // 空白时段直接不要：一个词都没有的窗口不进时间轴（否则播放时会卡在空白上）。
    // 只看入云的那批词 —— 被 topN 裁掉的词不撑窗口。
    final hasWords = List<bool>.filled(windowCount, false);
    for (final entry in selected) {
      final counts = perWindow[entry.key]!;
      for (var i = 0; i < windowCount; i++) {
        if (counts[i] > 0) hasWords[i] = true;
      }
    }
    final indexOf = List<int>.filled(windowCount, -1);
    final keptWindows = <WordCloudWindow>[];
    for (var i = 0; i < windowCount; i++) {
      if (!hasWords[i]) continue;
      indexOf[i] = keptWindows.length;
      keptWindows.add(windows[i]);
    }

    return WordCloudData(
      terms: [
        for (final entry in selected)
          WordCloudTerm(
            word: entry.key,
            total: entry.value,
            counts: List<int>.unmodifiable([
              for (var i = 0; i < windowCount; i++)
                if (indexOf[i] >= 0) perWindow[entry.key]![i],
            ]),
          ),
      ],
      windows: List<WordCloudWindow>.unmodifiable(keptWindows),
      unit: plan.unit,
      start: plan.t0,
      endExclusive: plan.t1,
      diaryCount: rows.length,
      tokenCount: tokenCount,
      activeFirst: 0,
      activeLast: keptWindows.isEmpty ? 0 : keptWindows.length - 1,
    );
  }
}
