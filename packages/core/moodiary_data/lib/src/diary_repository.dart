import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'diary_content_util.dart';

/// 倒排 / 链接索引的建立时机：[inline] 立即建（默认，非编辑器调用方）；[defer] 只写行 +
/// 入队，分词/倒排推迟到排空时建（编辑期内容有变）；[skip] 不建也不入队（编辑期仅改元
/// 数据，内容未变、索引仍有效）。
enum IndexMode { inline, defer, skip }

typedef _IndexEntry = ({
  int diaryIsarId,
  TokenizeResult? tokens,
  List<String> titleTokens,
  List<String> links,
  int contentChars,
});

/// 原始分词列表（含重复）→ 词 → 出现次数（BM25 的 TF）。
Map<String, int> _countTokens(List<String> raw) {
  final counts = <String, int>{};
  for (final t in raw) {
    counts[t] = (counts[t] ?? 0) + 1;
  }
  return counts;
}

/// 平行词频数组的容错读取：旧行缺该数组时按 1 处理（升级期自愈）。
int _freqAt(List<int> freqs, int i) => i < freqs.length ? freqs[i] : 1;

class DiaryRepository {
  DiaryRepository._(this._isar) : _rawTokenize = _defaultTokenize;

  factory DiaryRepository.get() => _instance;

  /// 测试用：注入独立 Isar 与替身分词器（宿主测试环境无 Rust FFI）。
  @visibleForTesting
  DiaryRepository.forTesting(
    this._isar, {
    Future<TokenizeResult> Function(String text)? tokenizer,
  }) : _rawTokenize = tokenizer ?? _defaultTokenize;

  static final DiaryRepository _instance = DiaryRepository._(
    IsarDatabase.get().isar,
  );

  final Isar _isar;

  final Future<TokenizeResult> Function(String text) _rawTokenize;

  static Future<TokenizeResult> _defaultTokenize(String text) =>
      Tokenizer.tokenize(text: text);

  final StreamController<DiaryEvent> _events =
      StreamController<DiaryEvent>.broadcast();

  Stream<DiaryEvent> get diaryEvents => _events.stream;

  Stream<Diary?> watchDiary(int isarId) => _isar.diarys.watchObject(isarId);

  // —— 倒排维护：posting-list（主键 get）+ 快照 diff。isar_plus 读查询不用二级索
  // 引（全表扫描），只有 @Id 主键是 O(1)，故 token/链接目标均以 fastHash 作主键组
  // 织；改动只触碰 diff 出的 posting 行，幂等（同内容重复应用不产生重复计权）。—— //

  static int _searchKey(TokenSource source, String token) =>
      fastHash('${source.name}:$token');

  static int _linkKey(String toId) => fastHash(toId);

  /// 对一组 posting 键做 upsert（含词频）/ 删除，同一键整批只读写一次；行空则删。
  /// [upserts]:键 → (diaryIsarId → tf)，已存在且 tf 相同则跳过。
  static void _mutateSearchPostings(
    Isar isar, {
    required Map<int, Map<int, int>> upserts,
    required Map<int, Set<int>> removes,
  }) {
    final keys = {...upserts.keys, ...removes.keys}.toList();
    if (keys.isEmpty) return;
    final col = isar.searchPostings;
    final existing = col.getAll(keys);
    final toPut = <SearchPosting>[];
    final toDelete = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final currentIds = existing[i]?.diaryIsarIds ?? const <int>[];
      final currentFreqs = existing[i]?.termFreqs ?? const <int>[];
      final removeSet = removes[key] ?? const <int>{};
      final upsertMap = upserts[key] ?? const <int, int>{};

      var changed = currentIds.any(removeSet.contains);
      if (!changed) {
        for (final e in upsertMap.entries) {
          final idx = currentIds.indexOf(e.key);
          if (idx < 0 || _freqAt(currentFreqs, idx) != e.value) {
            changed = true;
            break;
          }
        }
      }
      if (!changed) continue;

      final ids = <int>[];
      final freqs = <int>[];
      for (var j = 0; j < currentIds.length; j++) {
        final id = currentIds[j];
        if (removeSet.contains(id) || upsertMap.containsKey(id)) continue;
        ids.add(id);
        freqs.add(_freqAt(currentFreqs, j));
      }
      upsertMap.forEach((id, tf) {
        ids.add(id);
        freqs.add(tf);
      });
      if (ids.isEmpty) {
        toDelete.add(key);
      } else {
        toPut.add(SearchPosting(key: key, diaryIsarIds: ids, termFreqs: freqs));
      }
    }
    col.putAll(toPut);
    col.deleteAll(toDelete);
  }

  static void _mutateLinkPostings(
    Isar isar, {
    required Map<int, Set<int>> adds,
    required Map<int, Set<int>> removes,
  }) {
    final keys = {...adds.keys, ...removes.keys}.toList();
    if (keys.isEmpty) return;
    final col = isar.linkPostings;
    final existing = col.getAll(keys);
    final toPut = <LinkPosting>[];
    final toDelete = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final current = existing[i]?.fromIsarIds ?? const <int>[];
      final removeSet = removes[key] ?? const <int>{};
      final addSet = adds[key] ?? const <int>{};
      final changed =
          current.any(removeSet.contains) ||
          addSet.any((id) => !current.contains(id));
      if (!changed) continue;
      final next = <int>[
        for (final id in current)
          if (!removeSet.contains(id) && !addSet.contains(id)) id,
        ...addSet,
      ];
      if (next.isEmpty) {
        toDelete.add(key);
      } else {
        toPut.add(LinkPosting(key: key, fromIsarIds: next));
      }
    }
    col.putAll(toPut);
    col.deleteAll(toDelete);
  }

  /// 旧快照 → (posting 键 → tf) 映射；freq 数组缺失时按 1 容错。
  static Map<int, int> _snapshotSearchTf(DiaryIndexSnapshot? old) {
    if (old == null) return const {};
    final map = <int, int>{};
    for (var i = 0; i < old.cutTokens.length; i++) {
      map[_searchKey(TokenSource.cut, old.cutTokens[i])] =
          _freqAt(old.cutFreqs, i);
    }
    for (var i = 0; i < old.cutForSearchTokens.length; i++) {
      map[_searchKey(TokenSource.cutForSearch, old.cutForSearchTokens[i])] =
          _freqAt(old.cutForSearchFreqs, i);
    }
    for (var i = 0; i < old.titleTokens.length; i++) {
      map[_searchKey(TokenSource.title, old.titleTokens[i])] =
          _freqAt(old.titleFreqs, i);
    }
    return map;
  }

  /// 按快照 diff 批量把日记的分词（正文双源 + 标题，含词频）与双链目标写入倒排,
  /// 并增量维护 [SearchStats]。tokens 为 null 视作无内容。批内同 id 只保留最后一条
  /// （与顺序单篇应用等价），posting 聚合后每键只读写一次——高频词的 posting 行
  /// 不随批大小重复整行重写。词频变化视为变更（BM25 的 TF 必须跟随内容）。
  static void _applyIndexesBatch(Isar isar, List<_IndexEntry> entries) {
    if (entries.isEmpty) return;
    final byId = <int, _IndexEntry>{
      for (final e in entries) e.diaryIsarId: e,
    };
    final ids = byId.keys.toList();
    final olds = isar.diaryIndexSnapshots.getAll(ids);

    final searchUpserts = <int, Map<int, int>>{};
    final searchRemoves = <int, Set<int>>{};
    final linkAdds = <int, Set<int>>{};
    final linkRemoves = <int, Set<int>>{};
    final snapshots = <DiaryIndexSnapshot>[];
    var docDelta = 0;
    var contentDocDelta = 0;
    var charDelta = 0;

    for (var i = 0; i < ids.length; i++) {
      final e = byId[ids[i]]!;
      final old = olds[i];

      final cutCounts = _countTokens(e.tokens?.cut ?? const []);
      final cfsCounts = _countTokens(e.tokens?.cutForSearch ?? const []);
      final titleCounts = _countTokens(e.titleTokens);
      final newSearchTf = <int, int>{
        for (final t in cutCounts.entries)
          _searchKey(TokenSource.cut, t.key): t.value,
        for (final t in cfsCounts.entries)
          _searchKey(TokenSource.cutForSearch, t.key): t.value,
        for (final t in titleCounts.entries)
          _searchKey(TokenSource.title, t.key): t.value,
      };
      final oldSearchTf = _snapshotSearchTf(old);

      newSearchTf.forEach((key, tf) {
        if (oldSearchTf[key] != tf) {
          searchUpserts.putIfAbsent(key, () => {})[e.diaryIsarId] = tf;
        }
      });
      for (final key in oldSearchTf.keys) {
        if (!newSearchTf.containsKey(key)) {
          searchRemoves.putIfAbsent(key, () => {}).add(e.diaryIsarId);
        }
      }

      final oldLinkKeys = <int>{
        for (final id in old?.linkToIds ?? const <String>[]) _linkKey(id),
      };
      final newLinkKeys = <int>{for (final id in e.links) _linkKey(id)};
      for (final key in newLinkKeys.difference(oldLinkKeys)) {
        linkAdds.putIfAbsent(key, () => {}).add(e.diaryIsarId);
      }
      for (final key in oldLinkKeys.difference(newLinkKeys)) {
        linkRemoves.putIfAbsent(key, () => {}).add(e.diaryIsarId);
      }

      if (old == null) {
        docDelta += 1;
        charDelta += e.contentChars;
        if (e.contentChars > 0) contentDocDelta += 1;
      } else {
        charDelta += e.contentChars - old.contentChars;
        contentDocDelta +=
            (e.contentChars > 0 ? 1 : 0) - (old.contentChars > 0 ? 1 : 0);
      }

      snapshots.add(
        DiaryIndexSnapshot(
          diaryIsarId: e.diaryIsarId,
          cutTokens: cutCounts.keys.toList(),
          cutFreqs: cutCounts.values.toList(),
          cutForSearchTokens: cfsCounts.keys.toList(),
          cutForSearchFreqs: cfsCounts.values.toList(),
          titleTokens: titleCounts.keys.toList(),
          titleFreqs: titleCounts.values.toList(),
          linkToIds: e.links,
          contentChars: e.contentChars,
        ),
      );
    }

    _mutateSearchPostings(isar, upserts: searchUpserts, removes: searchRemoves);
    _mutateLinkPostings(isar, adds: linkAdds, removes: linkRemoves);
    isar.diaryIndexSnapshots.putAll(snapshots);
    _bumpStats(
      isar,
      docDelta: docDelta,
      contentDocDelta: contentDocDelta,
      charDelta: charDelta,
    );
  }

  /// 增量维护搜索统计单例（与倒排同事务，保证一致）。
  static void _bumpStats(
    Isar isar, {
    required int docDelta,
    required int contentDocDelta,
    required int charDelta,
  }) {
    if (docDelta == 0 && contentDocDelta == 0 && charDelta == 0) return;
    final stats = isar.searchStats.get(0);
    isar.searchStats.put(
      SearchStats(
        id: 0,
        docCount: (stats?.docCount ?? 0) + docDelta,
        contentDocCount: (stats?.contentDocCount ?? 0) + contentDocDelta,
        totalContentChars: (stats?.totalContentChars ?? 0) + charDelta,
      ),
    );
  }

  /// 把一批日记从全部倒排中摘除并删快照（软删/硬删共用），同键聚合只读写一次。
  static void _clearIndexesBatch(Isar isar, List<int> diaryIsarIds) {
    if (diaryIsarIds.isEmpty) return;
    final olds = isar.diaryIndexSnapshots.getAll(diaryIsarIds);
    final searchRemoves = <int, Set<int>>{};
    final linkRemoves = <int, Set<int>>{};
    var docDelta = 0;
    var contentDocDelta = 0;
    var charDelta = 0;
    for (var i = 0; i < diaryIsarIds.length; i++) {
      final old = olds[i];
      if (old == null) continue;
      final id = diaryIsarIds[i];
      for (final key in _snapshotSearchTf(old).keys) {
        searchRemoves.putIfAbsent(key, () => {}).add(id);
      }
      for (final toId in old.linkToIds) {
        linkRemoves.putIfAbsent(_linkKey(toId), () => {}).add(id);
      }
      docDelta -= 1;
      if (old.contentChars > 0) contentDocDelta -= 1;
      charDelta -= old.contentChars;
    }
    _mutateSearchPostings(isar, upserts: const {}, removes: searchRemoves);
    _mutateLinkPostings(isar, adds: const {}, removes: linkRemoves);
    isar.diaryIndexSnapshots.deleteAll(diaryIsarIds);
    _bumpStats(
      isar,
      docDelta: docDelta,
      contentDocDelta: contentDocDelta,
      charDelta: charDelta,
    );
  }

  static void _clearIndexes(Isar isar, int diaryIsarId) =>
      _clearIndexesBatch(isar, [diaryIsarId]);

  Future<TokenizeResult?> _tokenize(String text) async {
    if (text.isEmpty) return null;
    try {
      return await _rawTokenize(text);
    } catch (_) {
      return null;
    }
  }

  /// 正文 + 标题双分词构建索引条目。标题取细粒度分词（cutForSearch），召回更好。
  Future<_IndexEntry> _buildEntry(Diary diary) async {
    final tokens = await _tokenize(diary.contentText.trim());
    final title = await _tokenize(diary.title.trim());
    return (
      diaryIsarId: diary.isarId,
      tokens: tokens,
      titleTokens: title?.cutForSearch ?? const [],
      links: DiaryContentUtil.extractLinks(diary),
      contentChars: diary.contentText.length,
    );
  }

  Future<void> insertADiary(Diary diary) => insertDiaries([diary]);

  /// 批量插入（云 pull / JSON 导入等本地批处理入口）。posting 变更整批聚合、单事务
  /// 落库：高频词的 posting 行每批只重写一次，而逐篇 insert 会让该行随已插入篇数
  /// 线性变长地反复整行重写（O(N²)）。
  Future<void> insertDiaries(List<Diary> diaries) async {
    if (diaries.isEmpty) return;
    // 墓碑（备份里的已删日记）只落行、清倒排，不建索引。
    final entries = <_IndexEntry>[
      for (final diary in diaries)
        if (!diary.deleted) await _buildEntry(diary),
    ];
    final tombstoneIds = [
      for (final diary in diaries)
        if (diary.deleted) diary.isarId,
    ];
    await _isar.writeAsync((isar) {
      isar.diarys.putAll(diaries);
      _applyIndexesBatch(isar, entries);
      _clearIndexesBatch(isar, tombstoneIds);
    });
    for (final diary in diaries) {
      _events.add(DiaryCreated(diary));
    }
  }

  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = IndexMode.inline,
  }) async {
    // 墓碑不入倒排：与 deleteADiary / rebuildAllIndexes 保持同一不变量
    // （已索引 ⇔ 日记存在且未删）。同步引擎写 tombstone 走的就是本方法。
    if (newDiary.deleted) {
      await _isar.writeAsync((isar) {
        isar.diarys.put(newDiary);
        _clearIndexesBatch(isar, [newDiary.isarId]);
      });
      _events.add(DiaryUpdated(newDiary));
      return;
    }
    if (index != IndexMode.inline) {
      // 编辑期：只写日记行（defer 时一并入队），分词/倒排推迟到关闭/启动排空；skip 连
      // 入队都免（内容未变，索引仍有效）。同一次 writeAsync 落盘，少一次提交。
      await _isar.writeAsync((isar) {
        isar.diarys.put(newDiary);
        if (index == IndexMode.defer) {
          isar.reindexQueues.put(ReindexQueue(diaryIsarId: newDiary.isarId));
        }
      });
      _events.add(DiaryUpdated(newDiary));
      return;
    }
    await _isar.writeAsync((isar) {
      isar.diarys.put(newDiary);
    });
    _events.add(DiaryUpdated(newDiary));
    final entry = await _buildEntry(newDiary);
    await _isar.writeAsync((isar) {
      _applyIndexesBatch(isar, [entry]);
    });
  }

  /// 重建单篇日记的搜索 / 链接索引（队列排空时调用），完成后在同一事务出队。幂等：可重复
  /// 调用、可与另一次排空并发（最多多做一遍）；日记已硬删则清残留倒排后出队。
  Future<void> reindexDiary(int diaryIsarId) async {
    final diary = await _isar.diarys.getAsync(diaryIsarId);
    // 已硬删或已成墓碑：清残留倒排后出队（入队后可能被同步 tombstone）。
    if (diary == null || diary.deleted) {
      await _isar.writeAsync((isar) {
        _clearIndexes(isar, diaryIsarId);
        isar.reindexQueues.delete(diaryIsarId);
      });
      return;
    }
    final entry = await _buildEntry(diary);
    await _isar.writeAsync((isar) {
      _applyIndexesBatch(isar, [entry]);
      isar.reindexQueues.delete(diaryIsarId);
    });
  }

  /// 排空「待重索引」队列（关闭编辑器 / 启动恢复时调用）。返回处理篇数。
  Future<int> drainReindexQueue() async {
    final pending = await _isar.reindexQueues.where().findAllAsync();
    for (final entry in pending) {
      await reindexDiary(entry.diaryIsarId);
    }
    return pending.length;
  }

  Future<List<Diary>> getDiaryByCategory({
    String? categoryId,
    int? offset,
    int? limit,
    DiarySort sort = DiarySort.timeDesc,
  }) async {
    final base = _isar.diarys.where().showEqualTo(true).deletedEqualTo(false);
    final filtered = categoryId == null
        ? base
        : base.categoryIdEqualTo(categoryId);
    final sorted = switch (sort) {
      DiarySort.timeDesc => filtered.sortByTimeDesc().thenByIsarIdDesc(),
      DiarySort.timeAsc => filtered.sortByTime().thenByIsarId(),
      DiarySort.lastModifiedDesc =>
        filtered.sortByLastModifiedDesc().thenByIsarIdDesc(),
    };
    return sorted.findAllAsync(offset: offset, limit: limit);
  }

  /// 每个分类下「可见」日记的数量（categoryId -> count）与可见总数（含未分类），
  /// 供分类管理页 / 切换面板展示。只取 categoryId 属性、在 Dart 侧计数，避免载入整篇。
  Future<({Map<String, int> byCategory, int total})>
  diaryCountByCategory() async {
    final ids = await _isar.diarys
        .where()
        .showEqualTo(true)
        .deletedEqualTo(false)
        .categoryIdProperty()
        .findAllAsync();
    final counts = <String, int>{};
    for (final id in ids) {
      if (id != null && id.isNotEmpty) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return (byCategory: counts, total: ids.length);
  }

  Future<Diary?> getDiaryByID(int isarId) async {
    return await _isar.diarys.getAsync(isarId);
  }

  Future<Diary?> getDiaryByBusinessId(String id) async {
    // isarId 即 fastHash(id)，主键 get O(1)；idEqualTo 会整表扫描（引擎不用二级索引）。
    return await _isar.diarys.getAsync(fastHash(id));
  }

  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end, {
    bool all = true,
  }) async {
    return await _isar.diarys
        .where()
        .timeBetween(start, end)
        .showEqualTo(all)
        .deletedEqualTo(false)
        .findAllAsync();
  }

  /// 含回收站的全量日记（同步快照 / dashboard 统计用）。
  Future<List<Diary>> getAllDiaries() async {
    return await _isar.diarys.where().findAllAsync();
  }

  Future<List<Diary>> getAllDiariesSorted() async {
    return _isar.diarys
        .where()
        .showEqualTo(true)
        .deletedEqualTo(false)
        .sortByTimeDesc()
        .findAllAsync();
  }

  /// 软删除：标记 deleted，清倒排索引，清理本地媒体。
  Future<bool> deleteADiary(int isarId) async {
    final diary = await _isar.diarys.getAsync(isarId);
    if (diary == null) return false;
    await _isar.writeAsync((isar) {
      isar.diarys.put(
        diary.copyWith(
          deleted: true,
          show: true,
          lastModified: DateTime.timestamp(),
        ),
      );
      _clearIndexes(isar, isarId);
    });
    _events.add(DiaryUpdated(diary.copyWith(deleted: true, show: true)));
    await _cleanLocalMedia(diary);
    return true;
  }

  /// 硬删除（同步引擎推完 tombstone 后调用）。
  Future<void> deleteDiariesByIsarIds(List<int> isarIds) async {
    await _isar.writeAsync((isar) {
      isar.diarys.deleteAll(isarIds);
      _clearIndexesBatch(isar, isarIds);
    });
    for (final id in isarIds) {
      _events.add(DiaryDeleted(id));
    }
  }

  /// 草稿丢弃：直接移除 + 清理媒体，不保留 tombstone。
  Future<bool> hardDeleteDiary(int isarId) async {
    final diary = await _isar.diarys.getAsync(isarId);
    if (diary == null) return false;
    await _cleanLocalMedia(diary);
    await deleteDiariesByIsarIds([isarId]);
    return true;
  }

  static Future<void> _cleanLocalMedia(Diary diary) async {
    for (final name in diary.imageName) {
      try {
        await FileUtil.deleteFile(FileUtil.getRealPath('image', name));
      } catch (_) {}
    }
    for (final name in diary.audioName) {
      try {
        await FileUtil.deleteFile(FileUtil.getRealPath('audio', name));
      } catch (_) {}
    }
    for (final name in diary.videoName) {
      try {
        await FileUtil.deleteFile(FileUtil.getRealPath('video', name));
        final thumbName = 'thumbnail-${name.substring(6, 42)}.jpeg';
        await FileUtil.deleteFile(FileUtil.getRealPath('video', thumbName));
      } catch (_) {}
    }
  }

  Future<List<Diary>> getRecycleBinDiaries() async {
    return await _isar.diarys
        .where()
        .showEqualTo(false)
        .deletedEqualTo(false)
        .sortByTimeDesc()
        .thenByIsarIdDesc()
        .findAllAsync();
  }

  /// 按类型分页取「在册」日记（排除回收站/墓碑）。
  Future<List<Diary>> getMediaSourceDiaries({
    required MediaType type,
    int? offset,
    int? limit,
  }) async {
    final base = _isar.diarys.where().showEqualTo(true).deletedEqualTo(false);
    final filtered = switch (type) {
      MediaType.image => base.imageNameIsNotEmpty(),
      MediaType.audio => base.audioNameIsNotEmpty(),
      MediaType.video => base.videoNameIsNotEmpty(),
    };
    // thenByIsarIdDesc 与 diarySortComparator(timeDesc) 的次序一致，保证媒体库事件
    // 增量（applyDiaryEvent + 分页 offset）与库内顺序对齐，同 time 的日记不丢不重。
    return filtered
        .sortByTimeDesc()
        .thenByIsarIdDesc()
        .findAllAsync(offset: offset, limit: limit);
  }

  /// 汇全集引用的媒体文件名（含回收站/草稿/墓碑），供孤儿清理用。
  Future<({Set<String> images, Set<String> audios, Set<String> videos})>
  collectReferencedMedia() async {
    final diaries = await _isar.diarys.where().findAllAsync();
    final images = <String>{};
    final audios = <String>{};
    final videos = <String>{};
    for (final d in diaries) {
      images.addAll(d.imageName);
      audios.addAll(d.audioName);
      videos.addAll(d.videoName);
      for (final name in d.videoName) {
        final thumb = _thumbnailName(name);
        if (thumb != null) videos.add(thumb);
      }
    }
    return (images: images, audios: audios, videos: videos);
  }

  static String? _thumbnailName(String videoName) {
    if (videoName.length < 42) return null;
    return 'thumbnail-${videoName.substring(6, 42)}.jpeg';
  }

  /// BM25 字段加权。IDF/TF/DF 来自 posting（词频平行数组、行长），N 与 avgdl 来自
  /// [SearchStats]；正文源按 contentText 字符数做长度归一，标题源不归一（标题天然短）。
  static const _bm25K1 = 1.2;
  static const _bm25B = 0.4;
  static const _weightCut = 1.0;
  static const _weightCutForSearch = 0.5;
  static const _weightTitle = 1.5;

  Future<List<Diary>> searchDiaries({
    required List<String> cutTokens,
    required List<String> cutForSearchTokens,
    String? categoryId,
    DateTime? start,
    DateTime? end,
    SearchSort sort = SearchSort.relevance,
  }) async {
    if (cutTokens.isEmpty && cutForSearchTokens.isEmpty) return [];

    final stats = await _isar.searchStats.getAsync(0);
    final n = stats?.docCount ?? 0;
    // avgdl 只对正文非空的日记平均，纯媒体日记不摊薄均长。
    final avgChars = (stats == null || stats.contentDocCount <= 0)
        ? 1.0
        : stats.totalContentChars / stats.contentDocCount;

    // 候选 → 每个命中词的 (idf × 源权重, tf, 是否长度归一)。查询词先去重，避免重复计分。
    final hits = <int, List<(double, int, bool)>>{};

    Future<void> probe(
      TokenSource source,
      Iterable<String> words,
      double weight, {
      required bool lengthNorm,
    }) async {
      for (final word in words) {
        final posting = await _isar.searchPostings.getAsync(
          _searchKey(source, word),
        );
        if (posting == null) continue;
        final df = posting.diaryIsarIds.length;
        final idf = log(1 + (max(n, df) - df + 0.5) / (df + 0.5));
        for (var i = 0; i < posting.diaryIsarIds.length; i++) {
          hits.putIfAbsent(posting.diaryIsarIds[i], () => []).add((
            idf * weight,
            _freqAt(posting.termFreqs, i),
            lengthNorm,
          ));
        }
      }
    }

    final cutSet = cutTokens.toSet();
    final cfsSet = cutForSearchTokens.toSet();
    await probe(TokenSource.cut, cutSet, _weightCut, lengthNorm: true);
    await probe(
      TokenSource.cutForSearch,
      cfsSet,
      _weightCutForSearch,
      lengthNorm: true,
    );
    // 标题索引本身是细粒度分词，用查询的全部词形探测。
    await probe(
      TokenSource.title,
      {...cutSet, ...cfsSet},
      _weightTitle,
      lengthNorm: false,
    );

    if (hits.isEmpty) return [];

    final allDiaries = await _isar.diarys.getAllAsync(hits.keys.toList());
    final validDiaries = allDiaries
        .whereType<Diary>()
        .where((d) => d.show && !d.deleted)
        .where((d) => categoryId == null || d.categoryId == categoryId)
        .where((d) => start == null || !d.time.isBefore(start))
        .where((d) => end == null || d.time.isBefore(end))
        .toList();

    final scores = <int, double>{};
    for (final d in validDiaries) {
      final lenNorm =
          1 - _bm25B + _bm25B * (d.contentText.length / avgChars);
      var score = 0.0;
      for (final (idfW, tf, norm) in hits[d.isarId]!) {
        score += idfW *
            (tf * (_bm25K1 + 1)) /
            (tf + _bm25K1 * (norm ? lenNorm : 1.0));
      }
      scores[d.isarId] = score;
    }

    validDiaries.sort((a, b) {
      switch (sort) {
        case SearchSort.relevance:
          final sa = scores[a.isarId] ?? 0;
          final sb = scores[b.isarId] ?? 0;
          if (sa != sb) return sb.compareTo(sa);
          return b.time.compareTo(a.time);
        case SearchSort.timeDesc:
          return b.time.compareTo(a.time);
        case SearchSort.timeAsc:
          return a.time.compareTo(b.time);
      }
    });

    return validDiaries;
  }

  /// 按原始查询串搜索（内部用 Rust 分词后走 [searchDiaries]，相关性排序）。供「双链 `[[` 选取」
  /// 等需要把用户输入当查询的场景用。空串 / 无 token 返回空列表；[limit] 截断结果条数。
  Future<List<Diary>> searchDiariesByText(
    String query, {
    SearchSort sort = SearchSort.relevance,
    int limit = 12,
  }) async {
    final result = await _tokenize(query.trim());
    if (result == null) return [];
    final list = await searchDiaries(
      cutTokens: result.cut,
      cutForSearchTokens: result.cutForSearch,
      sort: sort,
    );
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// 反向链接：返回正文里双链指向 [toId] 的源日记（按时间倒序，排除草稿 / 回收站 / 已删）。
  Future<List<Diary>> getBacklinks(String toId) async {
    if (toId.isEmpty) return [];
    final posting = await _isar.linkPostings.getAsync(_linkKey(toId));
    final unique = posting?.fromIsarIds ?? const <int>[];
    if (unique.isEmpty) return [];
    final diaries = await _isar.diarys.getAllAsync(unique);
    final valid = diaries
        .whereType<Diary>()
        .where((d) => d.show && !d.deleted)
        .toList();
    valid.sort((a, b) => b.time.compareTo(a.time));
    return valid;
  }

  /// 清空并重建全部倒排（全文 posting + 双链 posting + 快照），升级后的手动回填入口：
  /// 设置里的「重建索引」按钮与搜索页的升级提示都走这里。全量在内存聚合、单事务替换，
  /// 避免逐篇 diff 的重复读写。返回处理篇数。幂等，均由 `content` 重算、不改 `lastModified`。
  Future<int> rebuildAllIndexes() async {
    final diaries = await getAllDiaries();
    final postingIds = <int, List<int>>{};
    final postingTfs = <int, List<int>>{};
    final linkPostings = <int, List<int>>{};
    final snapshots = <DiaryIndexSnapshot>[];
    var totalChars = 0;
    var contentDocCount = 0;

    for (final diary in diaries) {
      // 墓碑不入倒排（与增量路径同一不变量）。
      if (diary.deleted) continue;
      final entry = await _buildEntry(diary);
      final cutCounts = _countTokens(entry.tokens?.cut ?? const []);
      final cfsCounts = _countTokens(entry.tokens?.cutForSearch ?? const []);
      final titleCounts = _countTokens(entry.titleTokens);

      void addSource(TokenSource source, Map<String, int> counts) {
        counts.forEach((t, tf) {
          final key = _searchKey(source, t);
          postingIds.putIfAbsent(key, () => []).add(diary.isarId);
          postingTfs.putIfAbsent(key, () => []).add(tf);
        });
      }

      addSource(TokenSource.cut, cutCounts);
      addSource(TokenSource.cutForSearch, cfsCounts);
      addSource(TokenSource.title, titleCounts);
      for (final toId in entry.links) {
        linkPostings.putIfAbsent(_linkKey(toId), () => []).add(diary.isarId);
      }
      totalChars += entry.contentChars;
      if (entry.contentChars > 0) contentDocCount += 1;
      snapshots.add(
        DiaryIndexSnapshot(
          diaryIsarId: diary.isarId,
          cutTokens: cutCounts.keys.toList(),
          cutFreqs: cutCounts.values.toList(),
          cutForSearchTokens: cfsCounts.keys.toList(),
          cutForSearchFreqs: cfsCounts.values.toList(),
          titleTokens: titleCounts.keys.toList(),
          titleFreqs: titleCounts.values.toList(),
          linkToIds: entry.links,
          contentChars: entry.contentChars,
        ),
      );
    }

    final searchRows = [
      for (final e in postingIds.entries)
        SearchPosting(
          key: e.key,
          diaryIsarIds: e.value,
          termFreqs: postingTfs[e.key]!,
        ),
    ];
    final linkRows = [
      for (final e in linkPostings.entries)
        LinkPosting(key: e.key, fromIsarIds: e.value),
    ];
    final statsRow = SearchStats(
      id: 0,
      docCount: snapshots.length,
      contentDocCount: contentDocCount,
      totalContentChars: totalChars,
    );
    await _isar.writeAsync((isar) {
      isar.searchPostings.clear();
      isar.linkPostings.clear();
      isar.diaryIndexSnapshots.clear();
      isar.searchStats.clear();
      isar.searchPostings.putAll(searchRows);
      isar.linkPostings.putAll(linkRows);
      isar.diaryIndexSnapshots.putAll(snapshots);
      isar.searchStats.put(statsRow);
    });
    // 任何一次全量重建都完成了升级后的一次性回填（搜索页提示据此收起）。
    await MoodiaryKVs.searchIndexBackfilled.set(true);
    return snapshots.length;
  }

  /// 全量数据修复：按 `content` 重推 `contentText` / 媒体引用、清失效 `categoryId`，
  /// 重建搜索索引。幂等，可反复执行。
  /// 不更新 `lastModified`——均为可由 `content` 重算的本地衍生数据，避免误触发同步层
  /// 的「用户编辑」判断。
  Future<DiaryRepairReport> repairData() async {
    final diaries = await _isar.diarys.where().findAllAsync();
    final categoryIds = (await _isar.categorys.where().findAllAsync())
        .map((category) => category.id)
        .toSet();

    final updates = <Diary>[];
    var contentTextFixed = 0;
    var mediaFixed = 0;
    var orphanCategoryFixed = 0;

    for (final diary in diaries) {
      var next = diary;
      var changed = false;

      final plain = DiaryContentUtil.derivePlainText(diary);
      if (plain != diary.contentText) {
        next = next.copyWith(contentText: plain);
        changed = true;
        contentTextFixed++;
      }

      final media = DiaryContentUtil.extractMedia(diary);
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
      await _isar.writeAsync((isar) {
        isar.diarys.putAll(updates);
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
