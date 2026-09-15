import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/extensions/fts5.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'diary_content.dart';
import 'media_item.dart';

enum IndexMode { inline, skip }

@lazySingleton
class DiaryRepository {
  DiaryRepository(this._db);

  final MoodiaryDatabase _db;

  // SQLite 变量数上限 32766，留足余量
  static const int _inChunk = 5000;

  final StreamController<DiaryEvent> _events =
      StreamController<DiaryEvent>.broadcast();

  Stream<DiaryEvent> get diaryEvents => _events.stream;

  static Diary _toDiary(
    DiaryRow r, {
    required List<String> images,
    required List<String> audios,
    required List<String> videos,
    required List<String> tags,
  }) {
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
      mood: DiaryMood.fromName(r.mood),
      weather: icon == null
          ? null
          : DiaryWeather(
              icon: icon,
              temp: r.weatherTemp,
              text: r.weatherText ?? '',
            ),
      imageName: images,
      audioName: audios,
      videoName: videos,
      tags: tags,
      placeId: r.placeId,
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
    mood: d.mood.name,
    type: d.type,
    aspect: Value(d.aspect),
    placeId: Value(d.placeId),
    weatherIcon: Value(d.weather?.icon),
    weatherTemp: Value(d.weather?.temp),
    weatherText: Value(d.weather?.text),
  );

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

  Future<void> _applyLinks(String id, List<String> links) async {
    await (_db.delete(_db.diaryLinks)..where((l) => l.srcId.equals(id))).go();
    if (links.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.diaryLinks, [
        for (final dst in links)
          DiaryLinksCompanion.insert(srcId: id, dstId: dst),
      ]);
    });
  }

  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) => insertDiaries([diary], fromSync: fromSync, index: index);

  Future<void> insertDiaries(
    List<Diary> diaries, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) async {
    if (diaries.isEmpty) return;
    await _db.transaction(() async {
      for (final diary in diaries) {
        await _upsertRow(diary);
        await _syncChildren(diary);
        if (index == .inline) {
          await _applyLinks(diary.id, DiaryContent.of(diary).links);
        }
      }
      await (_db.delete(_db.tombstones)..where(
            (t) => t.key.isIn([
              for (final diary in diaries) SyncTombstone.diaryKey(diary.id),
            ]),
          ))
          .go();
      if (index == .inline) {
        await _enqueueEmbed([for (final diary in diaries) diary.id]);
      }
    });
    for (final diary in diaries) {
      _events.add(DiaryCreated(diary, fromSync: fromSync));
    }
  }

  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = .inline,
    bool fromSync = false,
  }) async {
    assert(() {
      if (index == .skip) return true;
      final derived = DiaryContent.of(newDiary).media;
      return _sameNameSet(newDiary.imageName, derived.images) &&
          _sameNameSet(newDiary.videoName, derived.videos) &&
          _sameNameSet(newDiary.audioName, derived.audios);
    }(), '媒体三列与正文引用不一致：写入方漏了 withDerivedMedia（见 diary_derive.dart）');
    await _db.transaction(() async {
      await _upsertRow(newDiary);
      await _syncChildren(newDiary);
      if (index == .inline) {
        await _applyLinks(newDiary.id, DiaryContent.of(newDiary).links);
        await _enqueueEmbed([newDiary.id]);
      }
    });
    _events.add(DiaryUpdated(newDiary, fromSync: fromSync));
  }

  Future<void> setVisibility(Diary diary, {required bool show}) => updateADiary(
    newDiary: diary.copyWith(show: show, lastModified: .timestamp()),
    index: .skip,
  );

  Future<bool> deleteADiary(String id) async {
    final diary = await getDiaryByBusinessId(id);
    if (diary == null) return false;
    await _tombstoneAndDelete(diary);
    await _cleanLocalMedia(diary);
    return true;
  }

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
      await _deleteRow(diary.id);
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

  Future<void> _deleteRow(String id) async {
    final deleted = await (_db.delete(
      _db.diaries,
    )..where((d) => d.id.equals(id))).go();
    if (deleted == 0) return;
    await _enqueueEmbed([id]);
  }

  Future<void> _enqueueEmbed(Iterable<String> ids) async {
    final at = dbTime(.timestamp());
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.embedQueue, [
        for (final id in ids)
          EmbedQueueCompanion.insert(diaryId: id, enqueuedAt: at),
      ]);
    });
  }

  Future<void> deleteDiariesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      for (final id in ids) {
        await _deleteRow(id);
      }
    });
    for (final id in ids) {
      _events.add(DiaryDeleted(id));
    }
  }

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
        await AppFiles.deleteImage(name);
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

  Future<int> countAllDiaries() async {
    final count = countAll();
    final q = _db.selectOnly(_db.diaries)..addColumns([count]);
    final row = await q.getSingle();
    return row.read(count)!;
  }

  Future<Diary?> getDiaryByBusinessId(String id) async {
    final row = await (_db.select(
      _db.diaries,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return _assembleOne(row);
  }

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

  Future<List<Diary>> getAllDiaries() async {
    return _assemble(await _db.select(_db.diaries).get());
  }

  Future<List<Diary>> getDiariesReferencingMedia({
    required MediaType kind,
    required List<String> suffixes,
  }) async {
    if (suffixes.isEmpty) return const [];
    final m = _db.diaryMedia;
    var match = m.fileName.lower().like('%${suffixes.first}');
    for (final suffix in suffixes.skip(1)) {
      match = match | m.fileName.lower().like('%$suffix');
    }
    final ids = _db.selectOnly(m, distinct: true)
      ..addColumns([m.diaryId])
      ..where(m.kind.equals(kind.value) & match);
    final hit = [for (final r in await ids.get()) r.read(m.diaryId)!];
    if (hit.isEmpty) return const [];
    return _assemble(
      await (_db.select(_db.diaries)..where((d) => d.id.isIn(hit))).get(),
    );
  }

  Future<List<Diary>> getLegacyFormatDiaries() async {
    final rows = await (_db.select(
      _db.diaries,
    )..where((d) => d.type.equals(DiaryType.tiptap.value).not())).get();
    return _assemble(rows);
  }

  Future<bool> hasLegacyFormatDiaries() async {
    final row =
        await (_db.select(_db.diaries)
              ..where((d) => d.type.equals(DiaryType.tiptap.value).not())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<List<Diary>> getDiariesWithPlace() async {
    final q = _visible()..where((d) => d.placeId.isNotNull());
    _orderBy(q, .timeDesc);
    return _assemble(await q.get());
  }

  Future<Map<String, int>> diaryCountByPlace() async {
    final place = _db.diaries.placeId;
    final count = countAll();
    final q = _db.selectOnly(_db.diaries)
      ..addColumns([place, count])
      ..where(_db.diaries.show.equals(1) & place.isNotNull())
      ..groupBy([place]);
    return {
      for (final row in await q.get()) row.read(place)!: row.read(count)!,
    };
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

  Future<List<MediaItem>> getMediaItems({
    required MediaType type,
    int? offset,
    int? limit,
  }) async {
    final m = _db.diaryMedia;
    final d = _db.diaries;
    final q = _db.selectOnly(m).join([innerJoin(d, d.id.equalsExp(m.diaryId))])
      ..addColumns([m.fileName, d.id, d.time])
      ..where(d.show.equals(1) & m.kind.equals(type.value))
      ..orderBy([
        OrderingTerm.desc(d.time),
        OrderingTerm.desc(d.id),
        OrderingTerm.asc(m.seq),
      ]);
    if (limit != null) q.limit(limit, offset: offset);
    return [
      for (final r in await q.get())
        MediaItem(
          fileName: r.read(m.fileName)!,
          diaryId: r.read(d.id)!,
          time: dbToTime(r.read(d.time)!),
        ),
    ];
  }

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
    final chatImages = _db.selectOnly(_db.chatMessages)
      ..addColumns([_db.chatMessages.imageName])
      ..where(_db.chatMessages.imageName.isNotNull());
    for (final row in await chatImages.get()) {
      final name = row.read(_db.chatMessages.imageName);
      if (name != null && name.isNotEmpty) images.add(name);
    }
    return (images: images, audios: audios, videos: videos);
  }

  static const _ftsRowId = CustomExpression<int>('${DiaryFts.$name}.rowid');

  /// 汉字切成词短语、拉丁串展开成拼音候选，多个词之间是 AND。
  Future<String> _matchExpression(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';
    final row = await _db
        .customSelect(
          'SELECT jieba_query(?) AS q',
          variables: [Variable<String>(trimmed)],
        )
        .getSingle();
    return row.read<String?>('q') ?? '';
  }

  /// 首次查询要现构造分词器，是百毫秒级的，所以搜索页打开时先热一次。
  Future<void> warmUpSearch() =>
      _db.customSelect("SELECT jieba_query('预热')").getSingle();

  Expression<bool> _searchPredicate(
    DiaryFts fts,
    Diaries d,
    String match,
    String? categoryId,
    DateTime? start,
    DateTime? end,
  ) {
    var where = fts.match(match) & d.show.equals(1);
    if (categoryId != null) where = where & d.categoryId.equals(categoryId);
    if (start != null) {
      where = where & d.time.isBiggerOrEqualValue(dbTime(start));
    }
    if (end != null) where = where & d.time.isSmallerThanValue(dbTime(end));
    return where;
  }

  /// 不取 highlight / snippet，所以可以对全量算。
  Future<int> countSearchDiaries({
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? end,
  }) async {
    final match = await _matchExpression(query);
    if (match.isEmpty) return 0;
    final fts = _db.diaryFts;
    final d = _db.diaries;
    final count = countAll();
    final select = _db.selectOnly(fts)
      ..addColumns([count])
      ..join([innerJoin(d, d.rid.equalsExp(_ftsRowId), useColumns: false)])
      ..where(_searchPredicate(fts, d, match, categoryId, start, end));
    return (await select.getSingle()).read(count) ?? 0;
  }

  /// highlight / snippet 要重新分词，成本按返回行数走，所以只给当前页算。
  Future<List<DiarySearchHit>> searchDiaries({
    required String query,
    String? categoryId,
    DateTime? start,
    DateTime? end,
    SearchSort sort = .relevance,
    int limit = -1,
    int offset = 0,
  }) async {
    final match = await _matchExpression(query);
    if (match.isEmpty) return const [];

    final fts = _db.diaryFts;
    final d = _db.diaries;
    final titleHit = fts.highlight(
      fts.title,
      before: searchHitStart,
      after: searchHitEnd,
    );
    final bodyHit = fts.snippet(
      fts.contentText,
      before: searchHitStart,
      after: searchHitEnd,
      ellipsis: '…',
      tokenCount: 24,
    );

    final select = _db.selectOnly(fts)
      ..addColumns([titleHit, bodyHit])
      ..join([innerJoin(d, d.rid.equalsExp(_ftsRowId), useColumns: true)])
      ..where(_searchPredicate(fts, d, match, categoryId, start, end));

    select.orderBy(switch (sort) {
      .relevance => [
        OrderingTerm.asc(fts.bm25(weights: const [1.5, 1.0])),
        OrderingTerm.desc(d.time),
        OrderingTerm.desc(d.id),
      ],
      .timeDesc => [OrderingTerm.desc(d.time), OrderingTerm.desc(d.id)],
      .timeAsc => [OrderingTerm.asc(d.time), OrderingTerm.asc(d.id)],
    });
    if (limit >= 0 || offset > 0) select.limit(limit, offset: offset);

    final rows = await select.get();
    final diaries = await _assemble([for (final r in rows) r.readTable(d)]);
    return [
      for (var i = 0; i < diaries.length; i++)
        DiarySearchHit(
          diary: diaries[i],
          titleHighlight: rows[i].read(titleHit) ?? diaries[i].title,
          excerpt: rows[i].read(bodyHit) ?? '',
        ),
    ];
  }

  Future<List<Diary>> getBacklinks(String toId) async {
    if (toId.isEmpty) return const [];
    final rows = await _db.backlinks(toId).get();
    return _assemble([for (final r in rows) r.d]);
  }

  Future<List<Diary>> getForwardLinks(String fromId) async {
    if (fromId.isEmpty) return const [];
    final rows = await _db.forwardLinks(fromId).get();
    return _assemble([for (final r in rows) r.d]);
  }

  Future<bool> hasAnyLink(String id) async {
    if (id.isEmpty) return false;
    return await _db.hasAnyLink(id).getSingle();
  }

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

  // centerIndex 恒为 0：中心节点排最前，Rust 布局的中心 pin 依赖这个顺序
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
    if (!visible.containsKey(rootId)) {
      return DiaryGraphData(nodes: const [], edges: Int32List(0));
    }
    final validEdges = <(String, String)>[];
    final connected = <String>{rootId};
    for (final (s, d) in candidateEdges) {
      if (!visible.containsKey(s) || !visible.containsKey(d)) continue;
      validEdges.add((s, d));
      connected
        ..add(s)
        ..add(d);
    }
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

  Future<int> rebuildAllIndexes() async {
    final diaries = await _assemble(await _db.select(_db.diaries).get());
    await _db.transaction(() async {
      await _db.delete(_db.diaryLinks).go();
      for (final diary in diaries) {
        final links = DiaryContent.of(diary).links;
        if (links.isEmpty) continue;
        await _db.batch((b) {
          b.insertAll(_db.diaryLinks, [
            for (final dst in links)
              DiaryLinksCompanion.insert(srcId: diary.id, dstId: dst),
          ]);
        });
      }
      await _db.customStatement(
        "INSERT INTO diary_fts(diary_fts) VALUES('rebuild')",
      );
    });
    MoodiaryKVs.searchIndexBackfilled.set(true);
    return diaries.length;
  }

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

  static bool _sameNameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }
}

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
