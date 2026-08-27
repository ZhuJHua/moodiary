import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/foundation.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'diary_content.dart';

/// 搜索 / 双链索引的建立时机：[inline] 与写行同事务原子建（默认——分词先行再开
/// 事务，SQLite 时代没有「分词夹不进事务」的两段式）；[skip] 不建（编辑期仅改
/// 元数据，内容未变、索引仍有效）。
enum IndexMode { inline, skip }

typedef _IndexEntry = ({
  String id,
  List<String> bodyTokens,
  List<String> titleTokens,
  List<String> links,
});

class DiaryRepository {
  DiaryRepository._(this._db);

  factory DiaryRepository.get() => _instance;

  /// 测试用：注入独立数据库。分词替身走 `RustLib.initMock`（moodiary_rust/testing.dart）。
  @visibleForTesting
  DiaryRepository.forTesting(this._db);

  static final DiaryRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  /// 批量分词每次过桥的条目数上限（限制单次桥载荷与内存峰值；128 篇已够铺满多核）。
  static const int _tokenizeChunk = 128;

  /// `WHERE x IN (...)` 的分块上限（SQLite 变量数上限 32766，留足余量）。
  static const int _inChunk = 5000;

  final StreamController<DiaryEvent> _events =
      StreamController<DiaryEvent>.broadcast();

  Stream<DiaryEvent> get diaryEvents => _events.stream;

  // —— 行 ↔ 域模型映射与子表装配 —— //

  static Diary _toDiary(
    DiaryRow r, {
    required List<String> images,
    required List<String> audios,
    required List<String> videos,
    required List<String> tags,
  }) {
    final lat = r.latitude;
    final icon = r.weatherIcon;
    return Diary(
      id: r.id,
      categoryId: r.categoryId,
      title: r.title,
      content: r.content,
      contentText: r.contentText,
      time: dbToTime(r.time),
      lastModified: dbToTime(r.lastModified),
      show: r.show != 0,
      mood: r.mood,
      weather: icon == null
          ? null
          : DiaryWeather(
              icon: icon,
              temp: r.weatherTemp!,
              text: r.weatherText!,
            ),
      imageName: images,
      audioName: audios,
      videoName: videos,
      tags: tags,
      position: lat == null
          ? null
          : DiaryPosition(
              latitude: lat,
              longitude: r.longitude!,
              name: r.placeName!,
            ),
      type: r.type,
      aspect: r.aspect,
    );
  }

  static DiariesCompanion _toCompanion(Diary d) => DiariesCompanion.insert(
    id: d.id,
    categoryId: Value(d.categoryId),
    title: d.title,
    content: d.content,
    contentText: d.contentText,
    time: dbTime(d.time),
    lastModified: dbTime(d.lastModified),
    show: d.show ? 1 : 0,
    mood: d.mood,
    type: d.type,
    aspect: Value(d.aspect),
    latitude: Value(d.position?.latitude),
    longitude: Value(d.position?.longitude),
    placeName: Value(d.position?.name),
    weatherIcon: Value(d.weather?.icon),
    weatherTemp: Value(d.weather?.temp),
    weatherText: Value(d.weather?.text),
  );

  /// 批量装配：一页行 → 域模型（子表按 id 分块 IN 批量取，无 N+1）。
  Future<List<Diary>> _assemble(List<DiaryRow> rows) async {
    if (rows.isEmpty) return const [];
    final mediaById = <String, Map<String, List<String>>>{};
    final tagsById = <String, List<String>>{};
    final ids = [for (final r in rows) r.id];
    for (var start = 0; start < ids.length; start += _inChunk) {
      final chunk = ids.sublist(start, min(start + _inChunk, ids.length));
      final media =
          await (_db.select(_db.diaryMedia)
                ..where((m) => m.diaryId.isIn(chunk))
                ..orderBy([(m) => OrderingTerm(expression: m.seq)]))
              .get();
      for (final m in media) {
        mediaById
            .putIfAbsent(m.diaryId, () => {})
            .putIfAbsent(m.kind, () => [])
            .add(m.fileName);
      }
      final tags =
          await (_db.select(_db.diaryTags)
                ..where((t) => t.diaryId.isIn(chunk))
                ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
              .get();
      for (final t in tags) {
        tagsById.putIfAbsent(t.diaryId, () => []).add(t.tag);
      }
    }
    return [
      for (final r in rows)
        _toDiary(
          r,
          images: mediaById[r.id]?['image'] ?? const [],
          audios: mediaById[r.id]?['audio'] ?? const [],
          videos: mediaById[r.id]?['video'] ?? const [],
          tags: tagsById[r.id] ?? const [],
        ),
    ];
  }

  Future<Diary?> _assembleOne(DiaryRow? row) async =>
      row == null ? null : (await _assemble([row])).first;

  // —— 分词与索引条目 —— //

  Future<TokenizeResult?> _tokenize(String text) async {
    if (text.isEmpty) return null;
    try {
      return await Tokenizer.tokenize(text: text);
    } catch (_) {
      return null;
    }
  }

  /// 索引侧只存 cut_for_search（高召回，含全词与子词；真实词频 = 重复次数）；
  /// 标题同样取细粒度分词。查询侧的 cut 词形是它的子集，天然可命中。
  Future<_IndexEntry> _buildEntry(Diary diary) async {
    final tokens = await _tokenize(diary.contentText.trim());
    final title = await _tokenize(diary.title.trim());
    return (
      id: diary.id,
      bodyTokens: tokens?.cutForSearch ?? const [],
      titleTokens: title?.cutForSearch ?? const [],
      links: DiaryContent.of(diary).links,
    );
  }

  /// 批量构建索引条目（[diaries] 应已按 [_tokenizeChunk] 分块）。整批的正文与标题
  /// 拼成一次分词调用，Rust 侧跨篇并行；长度不符或异常退回逐篇（宁慢不错位）。
  Future<List<_IndexEntry>> _buildEntries(List<Diary> diaries) async {
    if (diaries.length <= 1) {
      return [for (final diary in diaries) await _buildEntry(diary)];
    }
    // slot 编码：偶数 = 该篇正文，奇数 = 该篇标题；空文本不进批次。
    final texts = <String>[];
    final slots = <int>[];
    for (var i = 0; i < diaries.length; i++) {
      final content = diaries[i].contentText.trim();
      if (content.isNotEmpty) {
        texts.add(content);
        slots.add(i * 2);
      }
      final title = diaries[i].title.trim();
      if (title.isNotEmpty) {
        texts.add(title);
        slots.add(i * 2 + 1);
      }
    }
    List<TokenizeResult>? results;
    if (texts.isNotEmpty) {
      try {
        final out = await Tokenizer.tokenizeBatch(texts: texts);
        results = out.length == texts.length ? out : null;
      } catch (_) {
        results = null;
      }
      if (results == null) {
        return [for (final diary in diaries) await _buildEntry(diary)];
      }
    }
    final bodyTokens = List<List<String>?>.filled(diaries.length, null);
    final titleTokens = List<List<String>?>.filled(diaries.length, null);
    for (var k = 0; k < slots.length; k++) {
      final slot = slots[k];
      if (slot.isEven) {
        bodyTokens[slot ~/ 2] = results![k].cutForSearch;
      } else {
        titleTokens[slot ~/ 2] = results![k].cutForSearch;
      }
    }
    return [
      for (var i = 0; i < diaries.length; i++)
        (
          id: diaries[i].id,
          bodyTokens: bodyTokens[i] ?? const <String>[],
          titleTokens: titleTokens[i] ?? const <String>[],
          links: DiaryContent.of(diaries[i]).links,
        ),
    ];
  }

  // —— 事务内的写原语（调用方负责包 transaction）—— //

  /// upsert 日记行（冲突键 = 业务 id），返回 rid。
  Future<int> _upsertRow(Diary d) async {
    final row = await _db
        .into(_db.diaries)
        .insertReturning(
          _toCompanion(d),
          onConflict: DoUpdate(
            (_) => _toCompanion(d),
            target: [_db.diaries.id],
          ),
        );
    return row.rid;
  }

  /// 媒体三列 + 标签子表与行同步（每次写行都做——它们是行的一部分）。
  Future<void> _syncChildren(Diary d) async {
    await (_db.delete(
      _db.diaryMedia,
    )..where((m) => m.diaryId.equals(d.id))).go();
    await (_db.delete(
      _db.diaryTags,
    )..where((t) => t.diaryId.equals(d.id))).go();
    await _db.batch((b) {
      b.insertAll(_db.diaryMedia, [
        for (final (kind, names) in [
          ('image', d.imageName),
          ('audio', d.audioName),
          ('video', d.videoName),
        ])
          for (var i = 0; i < names.length; i++)
            DiaryMediaCompanion.insert(
              diaryId: d.id,
              kind: kind,
              seq: i,
              fileName: names[i],
            ),
      ]);
      b.insertAll(_db.diaryTags, [
        for (var i = 0; i < d.tags.length; i++)
          DiaryTagsCompanion.insert(diaryId: d.id, seq: i, tag: d.tags[i]),
      ]);
    });
  }

  /// FTS 行（按 rid 寻址——FTS5 的引擎约束）与双链边整体替换（幂等）。
  Future<void> _applyIndex(int rid, String id, _IndexEntry e) async {
    await _db.ftsDelete(rid);
    if (e.bodyTokens.isNotEmpty || e.titleTokens.isNotEmpty) {
      await _db.ftsInsert(
        rid,
        e.titleTokens.isEmpty ? null : e.titleTokens.join(' '),
        e.bodyTokens.isEmpty ? null : e.bodyTokens.join(' '),
      );
    }
    await (_db.delete(_db.diaryLinks)..where((l) => l.srcId.equals(id))).go();
    if (e.links.isNotEmpty) {
      await _db.batch((b) {
        b.insertAll(_db.diaryLinks, [
          for (final dst in e.links)
            DiaryLinksCompanion.insert(srcId: id, dstId: dst),
        ]);
      });
    }
  }

  // —— 写路径 —— //

  /// [fromSync] = 该写入由活跃云后端的 pull 落库（远端已持有），事件携带此标记
  /// 供 AutoSyncWatcher 免除回声推送；归档导入 / 局域网接收传 false。
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) => insertDiaries([diary], fromSync: fromSync, index: index);

  /// 批量插入（云 pull / JSON 导入等本地批处理入口）。分词在事务外整批完成
  /// （跨篇并行），行 + 子表 + FTS + 双链单事务原子落库。
  Future<void> insertDiaries(
    List<Diary> diaries, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) async {
    if (diaries.isEmpty) return;
    final entries = <_IndexEntry>[];
    if (index == .inline) {
      for (var start = 0; start < diaries.length; start += _tokenizeChunk) {
        final end = min(start + _tokenizeChunk, diaries.length);
        entries.addAll(await _buildEntries(diaries.sublist(start, end)));
      }
    }
    await _db.transaction(() async {
      for (var i = 0; i < diaries.length; i++) {
        final diary = diaries[i];
        final rid = await _upsertRow(diary);
        await _syncChildren(diary);
        if (index == .inline) await _applyIndex(rid, diary.id, entries[i]);
      }
      // 复活闸门：同 id 的同步墓碑连带清除，历史推送记录不会误判下一次删除。
      await (_db.delete(_db.tombstones)..where(
            (t) => t.key.isIn([
              for (final diary in diaries) SyncTombstone.diaryKey(diary.id),
            ]),
          ))
          .go();
    });
    for (final diary in diaries) {
      _events.add(DiaryCreated(diary, fromSync: fromSync));
    }
  }

  /// [fromSync] 语义同 [insertADiary]；编辑器迁移等「远端已持有等价内容」的本机改写
  /// 也走此标记，免得被当作待推变更。
  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = .inline,
    bool fromSync = false,
  }) async {
    // 派生一致性闸门（debug 期抓第四个写入方）：媒体三列必须等于正文引用——
    // 改了 content 的写入方要过 withDerivedMedia（diary_derive.dart）。
    // 只审 inline（真的动了内容的写入）：.skip 写入（软删/改元数据）没碰 content，
    // 回灌的旧格式行会被误炸。判据用集合而非顺序（与 repairData 的 _sameNameSet
    // 同源）。contentText 不在此断言内：编辑器的纯文本由 webview 侧提取，与
    // DiaryContent 的序列化不保证逐字节一致。
    assert(() {
      if (index == .skip) return true;
      final derived = DiaryContent.of(newDiary).media;
      return _sameNameSet(newDiary.imageName, derived.images) &&
          _sameNameSet(newDiary.videoName, derived.videos) &&
          _sameNameSet(newDiary.audioName, derived.audios);
    }(), '媒体三列与正文引用不一致：写入方漏了 withDerivedMedia（见 diary_derive.dart）');
    final entry = index == .inline ? await _buildEntry(newDiary) : null;
    await _db.transaction(() async {
      final rid = await _upsertRow(newDiary);
      await _syncChildren(newDiary);
      if (entry != null) await _applyIndex(rid, newDiary.id, entry);
    });
    _events.add(DiaryUpdated(newDiary, fromSync: fromSync));
  }

  /// 软删 / 还原：只翻 show 并 bump lastModified（用户操作，LWW 需要赢）；
  /// 索引 skip——它只看内容/标题，show 过滤在查询期。
  Future<void> setVisibility(Diary diary, {required bool show}) => updateADiary(
    newDiary: diary.copyWith(show: show, lastModified: .timestamp()),
    index: .skip,
  );

  /// 永久删除：行硬删（子表级联）+ FTS 摘除 + 写同步墓碑，清本地媒体。
  Future<bool> deleteADiary(String id) async {
    final diary = await getDiaryByBusinessId(id);
    if (diary == null) return false;
    await _tombstoneAndDelete(diary);
    await _cleanLocalMedia(diary);
    return true;
  }

  /// 同步 pull 应用远端墓碑：与 [deleteADiary] 同一事务形态，但媒体文件由
  /// 引擎的媒体端口清理（测试可注入），这里不动文件。返回写入的墓碑行。
  Future<SyncTombstone> tombstoneDiaryForSync(
    Diary diary, {
    bool fromSync = false,
  }) => _tombstoneAndDelete(diary, fromSync: fromSync);

  Future<SyncTombstone> _tombstoneAndDelete(
    Diary diary, {
    bool fromSync = false,
  }) async {
    final tombstone = SyncTombstone.forDiary(diary.id, at: .timestamp());
    await _db.transaction(() async {
      await _deleteRowAndIndex(diary.id);
      await _db
          .into(_db.tombstones)
          .insertOnConflictUpdate(_tombstoneCompanion(tombstone));
    });
    _events.add(DiaryDeleted(diary.id, fromSync: fromSync));
    return tombstone;
  }

  static TombstonesCompanion _tombstoneCompanion(SyncTombstone t) =>
      TombstonesCompanion.insert(
        key: t.key,
        timeMs: t.timeMs,
        pushedBackendsJson: Value(dbStringList(t.pushedBackends)),
      );

  /// 事务内：删行（子表级联）+ FTS 摘除。行不存在则为 no-op。
  Future<void> _deleteRowAndIndex(String id) async {
    final row = await (_db.select(
      _db.diaries,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _db.ftsDelete(row.rid);
    await (_db.delete(_db.diaries)..where((d) => d.rid.equals(row.rid))).go();
  }

  /// 硬删除且不留墓碑（草稿丢弃等本地兜底路径）。
  Future<void> deleteDiariesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      for (final id in ids) {
        await _deleteRowAndIndex(id);
      }
    });
    for (final id in ids) {
      _events.add(DiaryDeleted(id));
    }
  }

  /// 草稿丢弃：直接移除 + 清理媒体，不保留 tombstone。
  Future<bool> hardDeleteDiary(String id) async {
    final diary = await getDiaryByBusinessId(id);
    if (diary == null) return false;
    await _cleanLocalMedia(diary);
    await deleteDiariesByIds([id]);
    return true;
  }

  static Future<void> _cleanLocalMedia(Diary diary) async {
    for (final name in diary.imageName) {
      try {
        await AppFiles.deleteFile(AppFiles.getRealPath('image', name));
      } catch (_) {}
    }
    for (final name in diary.audioName) {
      try {
        await AppFiles.deleteFile(AppFiles.getRealPath('audio', name));
      } catch (_) {}
    }
    for (final name in diary.videoName) {
      try {
        await AppFiles.deleteFile(AppFiles.getRealPath('video', name));
        final thumbName = AppFiles.thumbnailNameOf(name);
        if (thumbName != null) {
          await AppFiles.deleteFile(AppFiles.getRealPath('video', thumbName));
        }
      } catch (_) {}
    }
  }

  // —— 读路径（真索引 seek + 过滤/排序/分页全部下推）—— //

  SimpleSelectStatement<Diaries, DiaryRow> _visible() =>
      _db.select(_db.diaries)..where((d) => d.show.equals(1));

  void _orderBy(SimpleSelectStatement<Diaries, DiaryRow> q, DiarySort sort) {
    switch (sort) {
      case .timeDesc:
        q.orderBy([
          (d) => OrderingTerm.desc(d.time),
          (d) => OrderingTerm.desc(d.id),
        ]);
      case .timeAsc:
        q.orderBy([
          (d) => OrderingTerm.asc(d.time),
          (d) => OrderingTerm.asc(d.id),
        ]);
      case .lastModifiedDesc:
        q.orderBy([
          (d) => OrderingTerm.desc(d.lastModified),
          (d) => OrderingTerm.desc(d.id),
        ]);
    }
  }

  /// [uncategorized] 为真时只取**没有分类**的日记；此时 [categoryId] 必须为 null。
  /// 「全部」与「未分类」都以 categoryId == null 表达，靠这个开关区分。
  Future<List<Diary>> getDiaryByCategory({
    String? categoryId,
    bool uncategorized = false,
    int? offset,
    int? limit,
    DiarySort sort = .timeDesc,
  }) async {
    assert(!(uncategorized && categoryId != null));
    final q = _visible();
    if (uncategorized) {
      q.where((d) => d.categoryId.isNull());
    } else if (categoryId != null) {
      q.where((d) => d.categoryId.equals(categoryId));
    }
    _orderBy(q, sort);
    if (limit != null) q.limit(limit, offset: offset);
    return _assemble(await q.get());
  }

  /// 按**本地月份**统计可见日记篇数（该月 1 号零点 -> 篇数）。分桶字段跟着 [sort]
  /// 走；只取一列时间属性、在 Dart 侧按本地时区分桶（SQL 按 UTC 分桶会错月）。
  Future<Map<DateTime, int>> diaryCountByMonth({
    String? categoryId,
    bool uncategorized = false,
    DiarySort sort = .timeDesc,
  }) async {
    assert(!(uncategorized && categoryId != null));
    final col = sort == .lastModifiedDesc
        ? _db.diaries.lastModified
        : _db.diaries.time;
    final q = _db.selectOnly(_db.diaries)
      ..addColumns([col])
      ..where(_db.diaries.show.equals(1));
    if (uncategorized) {
      q.where(_db.diaries.categoryId.isNull());
    } else if (categoryId != null) {
      q.where(_db.diaries.categoryId.equals(categoryId));
    }
    final counts = <DateTime, int>{};
    for (final row in await q.get()) {
      final local = dbToTime(row.read(col)!).toLocal();
      final key = DateTime(local.year, local.month);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// 每个分类下「可见」日记的数量（categoryId -> count）与可见总数（含未分类）。
  Future<({Map<String, int> byCategory, int total})>
  diaryCountByCategory() async {
    final cat = _db.diaries.categoryId;
    final count = countAll();
    final q = _db.selectOnly(_db.diaries)
      ..addColumns([cat, count])
      ..where(_db.diaries.show.equals(1))
      ..groupBy([cat]);
    final byCategory = <String, int>{};
    var total = 0;
    for (final row in await q.get()) {
      final n = row.read(count)!;
      total += n;
      final id = row.read(cat);
      if (id != null && id.isNotEmpty) byCategory[id] = n;
    }
    return (byCategory: byCategory, total: total);
  }

  Future<Diary?> getDiaryByBusinessId(String id) async {
    final row = await (_db.select(
      _db.diaries,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return _assembleOne(row);
  }

  /// [visibleOnly]=true 只取可见（默认，不含回收站）；false 只取回收站。
  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end, {
    bool visibleOnly = true,
  }) async {
    final rows =
        await (_db.select(_db.diaries)..where(
              (d) =>
                  d.show.equals(visibleOnly ? 1 : 0) &
                  d.time.isBetweenValues(dbTime(start), dbTime(end)),
            ))
            .get();
    return _assemble(rows);
  }

  /// 含回收站的全量日记（同步快照 / dashboard 统计用）。
  Future<List<Diary>> getAllDiaries() async {
    return _assemble(await _db.select(_db.diaries).get());
  }

  /// 旧编辑器格式（一切非 tiptap，含回收站）的日记——强制迁移的工作集。
  /// 用非等值而不是枚举等值：异常 type 值渲染时按 richText 兜底，迁移也必须带上。
  Future<List<Diary>> getLegacyFormatDiaries() async {
    final rows = await (_db.select(
      _db.diaries,
    )..where((d) => d.type.equals(DiaryType.tiptap.value).not())).get();
    return _assemble(rows);
  }

  /// 是否存在旧编辑器格式日记（启动闸门用，LIMIT 1 短路）。
  Future<bool> hasLegacyFormatDiaries() async {
    final row =
        await (_db.select(_db.diaries)
              ..where((d) => d.type.equals(DiaryType.tiptap.value).not())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// 地图用：只取带定位的可见日记（时间倒序）。
  Future<List<Diary>> getDiariesWithPosition() async {
    final q = _visible()..where((d) => d.latitude.isNotNull());
    _orderBy(q, .timeDesc);
    return _assemble(await q.get());
  }

  Future<List<Diary>> getRecycleBinDiaries() async {
    final q = _db.select(_db.diaries)
      ..where((d) => d.show.equals(0))
      ..orderBy([
        (d) => OrderingTerm.desc(d.time),
        (d) => OrderingTerm.desc(d.id),
      ]);
    return _assemble(await q.get());
  }

  /// 按类型分页取「在册」日记（排除回收站）。EXISTS 子查询走 diary_media 的
  /// kind 索引；排序第二键与 diarySortComparator 一致，分页 offset 才不丢不重。
  Future<List<Diary>> getMediaSourceDiaries({
    required MediaType type,
    int? offset,
    int? limit,
  }) async {
    final kind = switch (type) {
      .image => 'image',
      .audio => 'audio',
      .video => 'video',
    };
    final q = _visible()
      ..where(
        (d) => existsQuery(
          _db.select(_db.diaryMedia)
            ..where((m) => m.diaryId.equalsExp(d.id) & m.kind.equals(kind)),
        ),
      );
    _orderBy(q, .timeDesc);
    if (limit != null) q.limit(limit, offset: offset);
    return _assemble(await q.get());
  }

  /// 汇全集引用的媒体文件名（含回收站/草稿），供孤儿清理用。
  /// 子表即引用清单：一次全表读，不物化任何日记正文。
  Future<({Set<String> images, Set<String> audios, Set<String> videos})>
  collectReferencedMedia() async {
    final images = <String>{};
    final audios = <String>{};
    final videos = <String>{};
    for (final m in await _db.select(_db.diaryMedia).get()) {
      switch (m.kind) {
        case 'image':
          images.add(m.fileName);
        case 'audio':
          audios.add(m.fileName);
        case 'video':
          videos.add(m.fileName);
          final thumb = AppFiles.thumbnailNameOf(m.fileName);
          if (thumb != null) videos.add(thumb);
      }
    }
    return (images: images, audios: audios, videos: videos);
  }

  // —— 全文搜索（FTS5：MATCH 召回，bm25 引擎内打分）—— //

  /// FTS5 查询串：词加引号转义，OR 召回（与旧倒排的 union-probe 语义一致）。
  static String _matchQuery(Iterable<String> tokens) =>
      tokens.map((t) => '"${t.replaceAll('"', '""')}"').join(' OR ');

  Future<List<Diary>> searchDiaries({
    required List<String> cutTokens,
    required List<String> cutForSearchTokens,
    String? categoryId,
    DateTime? start,
    DateTime? end,
    SearchSort sort = .relevance,
    int limit = -1,
  }) async {
    final tokens = {...cutTokens, ...cutForSearchTokens}
      ..removeWhere((t) => t.trim().isEmpty);
    if (tokens.isEmpty) return const [];
    final match = _matchQuery(tokens);

    Expression<bool> pred(DiaryFts fts, Diaries d) {
      Expression<bool> e = const Constant(true);
      if (categoryId != null) e = e & d.categoryId.equals(categoryId);
      if (start != null) e = e & d.time.isBiggerOrEqualValue(dbTime(start));
      if (end != null) e = e & d.time.isSmallerThanValue(dbTime(end));
      return e;
    }

    final rows = switch (sort) {
      .relevance => [
        for (final r in await _db.ftsSearchByRank(match, pred, limit).get())
          r.d,
      ],
      .timeDesc => [
        for (final r
            in await _db
                .ftsSearchByTime(
                  match,
                  pred,
                  (fts, d) => OrderBy([
                    OrderingTerm.desc(d.time),
                    OrderingTerm.desc(d.id),
                  ]),
                  limit,
                )
                .get())
          r.d,
      ],
      .timeAsc => [
        for (final r
            in await _db
                .ftsSearchByTime(
                  match,
                  pred,
                  (fts, d) => OrderBy([
                    OrderingTerm.asc(d.time),
                    OrderingTerm.asc(d.id),
                  ]),
                  limit,
                )
                .get())
          r.d,
      ],
    };
    return _assemble(rows);
  }

  /// 按原始查询串搜索（Rust 分词后走 [searchDiaries]）。供「双链 `[[` 选取」等
  /// 需要把用户输入当查询的场景用。空串 / 无 token 返回空列表。
  Future<List<Diary>> searchDiariesByText(
    String query, {
    SearchSort sort = .relevance,
    int limit = 12,
  }) async {
    final result = await _tokenize(query.trim());
    if (result == null) return const [];
    return searchDiaries(
      cutTokens: result.cut,
      cutForSearchTokens: result.cutForSearch,
      sort: sort,
      limit: limit,
    );
  }

  // —— 双链 / 知识图谱 —— //

  /// 反向链接：正文里双链指向 [toId] 的源日记（时间倒序，排除回收站）。
  Future<List<Diary>> getBacklinks(String toId) async {
    if (toId.isEmpty) return const [];
    final rows = await _db.backlinks(toId).get();
    return _assemble([for (final r in rows) r.d]);
  }

  /// 正向链接：这篇日记正文里双链指向的目标日记（时间倒序，自链丢弃）。
  Future<List<Diary>> getForwardLinks(String fromId) async {
    if (fromId.isEmpty) return const [];
    final rows = await _db.forwardLinks(fromId).get();
    return _assemble([for (final r in rows) r.d]);
  }

  /// 这篇日记是否至少有一条出链或入链（详情页「关系图」入口显隐）。自链不算。
  Future<bool> hasAnyLink(String id) async {
    if (id.isEmpty) return false;
    return await _db.hasAnyLink(id).getSingle();
  }

  /// 图谱标签用的正文摘要：折叠空白后截前 [_graphPreviewChars] 个码点。
  static const _graphPreviewChars = 24;

  static String? _graphPreview(String contentText) {
    final flat = contentText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return null;
    final runes = flat.runes.toList();
    return runes.length <= _graphPreviewChars
        ? flat
        : .fromCharCodes(runes.take(_graphPreviewChars));
  }

  Future<Map<String, DiaryRow>> _visibleRowsByIds(Iterable<String> ids) async {
    final list = ids.toList();
    final out = <String, DiaryRow>{};
    for (var start = 0; start < list.length; start += _inChunk) {
      final chunk = list.sublist(start, min(start + _inChunk, list.length));
      final rows = await (_db.select(
        _db.diaries,
      )..where((d) => d.id.isIn(chunk) & d.show.equals(1))).get();
      for (final r in rows) {
        out[r.id] = r;
      }
    }
    return out;
  }

  static DiaryGraphNode _node(int index, DiaryRow d, {int? depth}) =>
      DiaryGraphNode(
        index: index,
        id: d.id,
        title: d.title,
        time: dbToTime(d.time),
        categoryId: d.categoryId,
        depth: depth,
        preview: _graphPreview(d.contentText),
      );

  /// 装配知识图谱数据：从 diary_links 直接取边。只含 linked-only 节点（至少一条
  /// 有效双链）；悬空边（指向已删/回收站日记）在 SQL 层丢弃。边为**有向** src→dst，
  /// 供 UI 画箭头；A↔B 互链保留为两条。节点按 time desc（id 兜底）稳定排序后
  /// 分配密集下标——供 Rust 布局与坐标数组一一对应。
  Future<DiaryGraphData> buildLinkGraph() async {
    final edges = await _db.visibleLinkEdges().get();
    if (edges.isEmpty) {
      return DiaryGraphData(nodes: const [], edges: Int32List(0));
    }
    final endpoints = <String>{};
    for (final e in edges) {
      endpoints
        ..add(e.srcId)
        ..add(e.dstId);
    }
    final byId = await _visibleRowsByIds(endpoints);
    final nodesSorted = byId.values.toList()
      ..sort((a, b) {
        final c = b.time.compareTo(a.time);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final indexOf = <String, int>{};
    final nodes = <DiaryGraphNode>[];
    for (var i = 0; i < nodesSorted.length; i++) {
      indexOf[nodesSorted[i].id] = i;
      nodes.add(_node(i, nodesSorted[i]));
    }
    final out = Int32List(edges.length * 2);
    for (var i = 0; i < edges.length; i++) {
      out[i * 2] = indexOf[edges[i].srcId]!;
      out[i * 2 + 1] = indexOf[edges[i].dstId]!;
    }
    return DiaryGraphData(nodes: nodes, edges: out);
  }

  /// 以 [rootId] 为中心的局部知识图谱（ego graph / k 跳邻域）。BFS 展开 [depth] 跳，
  /// 出链入链同时展开（不分方向），[depth] clamp 到 [1,3]，节点数按 [maxNodes] 截断
  /// （先排序再截，结果确定）。最外层多跑一轮「只读边不扩点」补成**诱导子图**。
  /// 节点排序 depth asc → time desc → id asc，中心是唯一的 depth 0，
  /// **故 centerIndex 恒为 0**——Rust 布局的中心 pin 依赖这一点，改排序必须同步改那边。
  /// 与 [buildLinkGraph] 的 linked-only 语义不同：中心节点即使无链接也在图里（孤点）。
  Future<DiaryGraphData> buildEgoGraph(
    String rootId, {
    int depth = 1,
    int maxNodes = 300,
  }) async {
    if (rootId.isEmpty) {
      return DiaryGraphData(nodes: const [], edges: Int32List(0));
    }
    final clampedDepth = depth.clamp(1, 3);
    final visitedDepth = <String, int>{rootId: 0};
    var frontier = <String>[rootId];
    final candidateEdges = <(String, String)>{};

    for (var currentDepth = 0; frontier.isNotEmpty; currentDepth++) {
      final discovered = <String>{};
      for (final e in await _db.outEdgesOf(frontier).get()) {
        candidateEdges.add((e.srcId, e.dstId));
        if (!visitedDepth.containsKey(e.dstId)) discovered.add(e.dstId);
      }
      for (final e in await _db.inEdgesOf(frontier).get()) {
        candidateEdges.add((e.srcId, e.dstId));
        if (!visitedDepth.containsKey(e.srcId)) discovered.add(e.srcId);
      }
      // 最后一轮只补边、不扩点。
      if (currentDepth >= clampedDepth) break;
      final budget = maxNodes - visitedDepth.length;
      if (budget <= 0) break;
      final next = discovered.toList()..sort();
      if (next.length > budget) next.length = budget;
      for (final id in next) {
        visitedDepth[id] = currentDepth + 1;
      }
      frontier = next;
    }

    final visible = await _visibleRowsByIds(visitedDepth.keys);
    // 中心自身已删 / 在回收站：整张图无意义。
    if (!visible.containsKey(rootId)) {
      return DiaryGraphData(nodes: const [], edges: Int32List(0));
    }
    // 两端都可见才保留（悬空链接 / 回收站 / 被 maxNodes 截掉的候选在此丢弃）。
    final validEdges = <(String, String)>[];
    final connected = <String>{rootId};
    for (final (s, d) in candidateEdges) {
      if (!visible.containsKey(s) || !visible.containsKey(d)) continue;
      validEdges.add((s, d));
      connected
        ..add(s)
        ..add(d);
    }
    // 只经由不可见节点才可达的深层孤岛剔除，恢复「非中心节点必有边」不变量。
    visible.removeWhere((id, _) => !connected.contains(id));

    final nodesSorted = visible.values.toList()
      ..sort((a, b) {
        final c = visitedDepth[a.id]!.compareTo(visitedDepth[b.id]!);
        if (c != 0) return c;
        final t = b.time.compareTo(a.time);
        return t != 0 ? t : a.id.compareTo(b.id);
      });
    final indexOf = <String, int>{};
    final nodes = <DiaryGraphNode>[];
    for (var i = 0; i < nodesSorted.length; i++) {
      final d = nodesSorted[i];
      indexOf[d.id] = i;
      nodes.add(_node(i, d, depth: visitedDepth[d.id]));
    }
    final out = Int32List(validEdges.length * 2);
    for (var i = 0; i < validEdges.length; i++) {
      out[i * 2] = indexOf[validEdges[i].$1]!;
      out[i * 2 + 1] = indexOf[validEdges[i].$2]!;
    }
    return DiaryGraphData(
      nodes: nodes,
      edges: out,
      centerIndex: indexOf[rootId],
    );
  }

  // —— 全量重建 / 修复 —— //

  /// 清空并重建全部 FTS 与双链边（设置里的「重建索引」按钮、升级回填、分词器
  /// 词典变更后的重灌入口）。contentless FTS5 无 'rebuild' 命令，走 delete-all +
  /// 整批重灌。返回处理篇数。幂等，均由 content 重算、不改 lastModified。
  Future<int> rebuildAllIndexes() async {
    final rows = await _db.select(_db.diaries).get();
    final ridOf = {for (final r in rows) r.id: r.rid};
    final diaries = await _assemble(rows);
    final entries = <_IndexEntry>[];
    for (var start = 0; start < diaries.length; start += _tokenizeChunk) {
      final end = min(start + _tokenizeChunk, diaries.length);
      entries.addAll(await _buildEntries(diaries.sublist(start, end)));
    }
    await _db.transaction(() async {
      await _db.customStatement(
        "INSERT INTO diary_fts(diary_fts) VALUES('delete-all')",
      );
      await _db.delete(_db.diaryLinks).go();
      for (final e in entries) {
        final rid = ridOf[e.id]!;
        if (e.bodyTokens.isNotEmpty || e.titleTokens.isNotEmpty) {
          await _db.ftsInsert(
            rid,
            e.titleTokens.isEmpty ? null : e.titleTokens.join(' '),
            e.bodyTokens.isEmpty ? null : e.bodyTokens.join(' '),
          );
        }
        if (e.links.isNotEmpty) {
          await _db.batch((b) {
            b.insertAll(_db.diaryLinks, [
              for (final dst in e.links)
                DiaryLinksCompanion.insert(srcId: e.id, dstId: dst),
            ]);
          });
        }
      }
    });
    // 任何一次全量重建都完成了升级后的一次性回填（搜索页提示据此收起）。
    MoodiaryKVs.searchIndexBackfilled.set(true);
    return entries.length;
  }

  /// 全量数据修复：按 `content` 重推 `contentText` / 媒体引用、清失效 `categoryId`，
  /// 重建搜索索引。幂等，可反复执行。不更新 `lastModified`——均为可由 `content`
  /// 重算的本地衍生数据，避免误触发同步层的「用户编辑」判断。
  Future<DiaryRepairReport> repairData() async {
    final diaries = await getAllDiaries();
    final categoryIds = {
      for (final row in await _db.select(_db.categories).get()) row.id,
    };

    final updates = <Diary>[];
    var contentTextFixed = 0;
    var mediaFixed = 0;
    var orphanCategoryFixed = 0;

    for (final diary in diaries) {
      var next = diary;
      var changed = false;
      final derived = DiaryContent.of(diary);

      final plain = derived.plainText;
      if (plain != diary.contentText) {
        next = next.copyWith(contentText: plain);
        changed = true;
        contentTextFixed++;
      }
      final media = derived.media;
      if (!_sameNameSet(media.images, diary.imageName) ||
          !_sameNameSet(media.videos, diary.videoName) ||
          !_sameNameSet(media.audios, diary.audioName)) {
        next = next.copyWith(
          imageName: media.images,
          videoName: media.videos,
          audioName: media.audios,
        );
        changed = true;
        mediaFixed++;
      }
      final categoryId = diary.categoryId;
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          !categoryIds.contains(categoryId)) {
        next = next.copyWith(categoryId: null);
        changed = true;
        orphanCategoryFixed++;
      }
      if (changed) updates.add(next);
    }

    if (updates.isNotEmpty) {
      await _db.transaction(() async {
        for (final diary in updates) {
          await _upsertRow(diary);
          await _syncChildren(diary);
        }
      });
      for (final diary in updates) {
        _events.add(DiaryUpdated(diary));
      }
    }

    final reindexed = await rebuildAllIndexes();
    return DiaryRepairReport(
      scanned: diaries.length,
      changed: updates.length,
      contentTextFixed: contentTextFixed,
      mediaFixed: mediaFixed,
      orphanCategoryFixed: orphanCategoryFixed,
      reindexed: reindexed,
    );
  }

  /// 文件名集合是否等价（忽略顺序）；仅顺序差异不算「需修正」，避免无谓写入。
  static bool _sameNameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }
}

/// [DiaryRepository.repairData] 的修复统计。
class DiaryRepairReport {
  final int scanned;

  final int changed;

  final int contentTextFixed;

  final int mediaFixed;

  final int orphanCategoryFixed;

  final int reindexed;

  const DiaryRepairReport({
    required this.scanned,
    required this.changed,
    required this.contentTextFixed,
    required this.mediaFixed,
    required this.orphanCategoryFixed,
    required this.reindexed,
  });

  bool get hasFix => changed > 0;
}
