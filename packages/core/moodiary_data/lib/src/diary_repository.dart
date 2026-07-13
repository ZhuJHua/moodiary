import 'dart:async';

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
  List<String> links,
});

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

  /// 对一组 posting 键做集合增删（同一键整批只读写一次），保持元素唯一；行空则删。
  static void _mutateSearchPostings(
    Isar isar, {
    required Map<int, Set<int>> adds,
    required Map<int, Set<int>> removes,
  }) {
    final keys = {...adds.keys, ...removes.keys}.toList();
    if (keys.isEmpty) return;
    final col = isar.searchPostings;
    final existing = col.getAll(keys);
    final toPut = <SearchPosting>[];
    final toDelete = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final current = existing[i]?.diaryIsarIds ?? const <int>[];
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
        toPut.add(SearchPosting(key: key, diaryIsarIds: next));
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

  /// 按快照 diff 批量把日记的全文分词与双链目标写入倒排。tokens 为 null 视作无内容。
  /// 批内同 id 只保留最后一条（与顺序单篇应用等价），posting 聚合后每键只读写一次——
  /// 高频词的 posting 行不随批大小重复整行重写。
  static void _applyIndexesBatch(Isar isar, List<_IndexEntry> entries) {
    if (entries.isEmpty) return;
    final byId = <int, _IndexEntry>{
      for (final e in entries) e.diaryIsarId: e,
    };
    final ids = byId.keys.toList();
    final olds = isar.diaryIndexSnapshots.getAll(ids);

    final searchAdds = <int, Set<int>>{};
    final searchRemoves = <int, Set<int>>{};
    final linkAdds = <int, Set<int>>{};
    final linkRemoves = <int, Set<int>>{};
    final snapshots = <DiaryIndexSnapshot>[];

    for (var i = 0; i < ids.length; i++) {
      final e = byId[ids[i]]!;
      final old = olds[i];
      final oldSearchKeys = <int>{
        for (final t in old?.cutTokens ?? const <String>[])
          _searchKey(TokenSource.cut, t),
        for (final t in old?.cutForSearchTokens ?? const <String>[])
          _searchKey(TokenSource.cutForSearch, t),
      };
      final cut = e.tokens?.cut ?? const <String>[];
      final cutForSearch = e.tokens?.cutForSearch ?? const <String>[];
      final newSearchKeys = <int>{
        for (final t in cut) _searchKey(TokenSource.cut, t),
        for (final t in cutForSearch) _searchKey(TokenSource.cutForSearch, t),
      };
      for (final key in newSearchKeys.difference(oldSearchKeys)) {
        searchAdds.putIfAbsent(key, () => {}).add(e.diaryIsarId);
      }
      for (final key in oldSearchKeys.difference(newSearchKeys)) {
        searchRemoves.putIfAbsent(key, () => {}).add(e.diaryIsarId);
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

      snapshots.add(
        DiaryIndexSnapshot(
          diaryIsarId: e.diaryIsarId,
          cutTokens: cut,
          cutForSearchTokens: cutForSearch,
          linkToIds: e.links,
        ),
      );
    }

    _mutateSearchPostings(isar, adds: searchAdds, removes: searchRemoves);
    _mutateLinkPostings(isar, adds: linkAdds, removes: linkRemoves);
    isar.diaryIndexSnapshots.putAll(snapshots);
  }

  static void _applyIndexes(
    Isar isar,
    int diaryIsarId, {
    required TokenizeResult? tokens,
    required List<String> links,
  }) {
    _applyIndexesBatch(isar, [
      (diaryIsarId: diaryIsarId, tokens: tokens, links: links),
    ]);
  }

  /// 把一批日记从全部倒排中摘除并删快照（软删/硬删共用），同键聚合只读写一次。
  static void _clearIndexesBatch(Isar isar, List<int> diaryIsarIds) {
    if (diaryIsarIds.isEmpty) return;
    final olds = isar.diaryIndexSnapshots.getAll(diaryIsarIds);
    final searchRemoves = <int, Set<int>>{};
    final linkRemoves = <int, Set<int>>{};
    for (var i = 0; i < diaryIsarIds.length; i++) {
      final old = olds[i];
      if (old == null) continue;
      final id = diaryIsarIds[i];
      for (final t in old.cutTokens) {
        searchRemoves
            .putIfAbsent(_searchKey(TokenSource.cut, t), () => {})
            .add(id);
      }
      for (final t in old.cutForSearchTokens) {
        searchRemoves
            .putIfAbsent(_searchKey(TokenSource.cutForSearch, t), () => {})
            .add(id);
      }
      for (final toId in old.linkToIds) {
        linkRemoves.putIfAbsent(_linkKey(toId), () => {}).add(id);
      }
    }
    _mutateSearchPostings(isar, adds: const {}, removes: searchRemoves);
    _mutateLinkPostings(isar, adds: const {}, removes: linkRemoves);
    isar.diaryIndexSnapshots.deleteAll(diaryIsarIds);
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

  Future<void> insertADiary(Diary diary) => insertDiaries([diary]);

  /// 批量插入（云 pull / JSON 导入等本地批处理入口）。posting 变更整批聚合、单事务
  /// 落库：高频词的 posting 行每批只重写一次，而逐篇 insert 会让该行随已插入篇数
  /// 线性变长地反复整行重写（O(N²)）。
  Future<void> insertDiaries(List<Diary> diaries) async {
    if (diaries.isEmpty) return;
    final entries = <_IndexEntry>[];
    for (final diary in diaries) {
      entries.add((
        diaryIsarId: diary.isarId,
        tokens: await _tokenize(diary.contentText.trim()),
        links: DiaryContentUtil.extractLinks(diary),
      ));
    }
    await _isar.writeAsync((isar) {
      isar.diarys.putAll(diaries);
      _applyIndexesBatch(isar, entries);
    });
    for (final diary in diaries) {
      _events.add(DiaryCreated(diary));
    }
  }

  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = IndexMode.inline,
  }) async {
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
    final result = await _tokenize(newDiary.contentText.trim());
    final links = DiaryContentUtil.extractLinks(newDiary);
    await _isar.writeAsync((isar) {
      _applyIndexes(isar, newDiary.isarId, tokens: result, links: links);
    });
  }

  /// 重建单篇日记的搜索 / 链接索引（队列排空时调用），完成后在同一事务出队。幂等：可重复
  /// 调用、可与另一次排空并发（最多多做一遍）；日记已硬删则清残留倒排后出队。
  Future<void> reindexDiary(int diaryIsarId) async {
    final diary = await _isar.diarys.getAsync(diaryIsarId);
    if (diary == null) {
      await _isar.writeAsync((isar) {
        _clearIndexes(isar, diaryIsarId);
        isar.reindexQueues.delete(diaryIsarId);
      });
      return;
    }
    final result = await _tokenize(diary.contentText.trim());
    final links = DiaryContentUtil.extractLinks(diary);
    await _isar.writeAsync((isar) {
      _applyIndexes(isar, diaryIsarId, tokens: result, links: links);
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

  /// 双倒排表加权搜索：cut 命中 +1.0，cutForSearch 命中 +0.5，标题 +0.3。
  Future<List<Diary>> searchDiaries({
    required List<String> cutTokens,
    required List<String> cutForSearchTokens,
    String? categoryId,
    DateTime? start,
    DateTime? end,
    SearchSort sort = SearchSort.relevance,
  }) async {
    if (cutTokens.isEmpty && cutForSearchTokens.isEmpty) return [];

    final scores = <int, double>{};
    final diaryIdSet = <int>{};

    for (final word in cutTokens) {
      final posting = await _isar.searchPostings.getAsync(
        _searchKey(TokenSource.cut, word),
      );
      for (final id in posting?.diaryIsarIds ?? const <int>[]) {
        scores[id] = (scores[id] ?? 0) + 1.0;
        diaryIdSet.add(id);
      }
    }

    for (final word in cutForSearchTokens) {
      final posting = await _isar.searchPostings.getAsync(
        _searchKey(TokenSource.cutForSearch, word),
      );
      for (final id in posting?.diaryIsarIds ?? const <int>[]) {
        scores[id] = (scores[id] ?? 0) + 0.5;
        diaryIdSet.add(id);
      }
    }

    final allQueryWords = {...cutTokens, ...cutForSearchTokens};
    for (final word in allQueryWords) {
      final titleMatches = await _isar.diarys
          .where()
          .showEqualTo(true)
          .deletedEqualTo(false)
          .titleContains(word, caseSensitive: false)
          .findAllAsync();
      for (final d in titleMatches) {
        if (diaryIdSet.add(d.isarId)) {
          scores[d.isarId] = 0.3;
        } else {
          scores[d.isarId] = (scores[d.isarId] ?? 0) + 0.3;
        }
      }
    }

    if (diaryIdSet.isEmpty) return [];

    final allDiaries = await _isar.diarys.getAllAsync(diaryIdSet.toList());
    final validDiaries = allDiaries
        .whereType<Diary>()
        .where((d) => d.show && !d.deleted)
        .where((d) => categoryId == null || d.categoryId == categoryId)
        .where((d) => start == null || !d.time.isBefore(start))
        .where((d) => end == null || d.time.isBefore(end))
        .toList();

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
    final searchPostings = <int, List<int>>{};
    final linkPostings = <int, List<int>>{};
    final snapshots = <DiaryIndexSnapshot>[];

    for (final diary in diaries) {
      final text = diary.contentText.trim();
      final tokens = text.isEmpty ? null : await _tokenize(text);
      final links = DiaryContentUtil.extractLinks(diary);
      final cut = tokens?.cut ?? const <String>[];
      final cutForSearch = tokens?.cutForSearch ?? const <String>[];
      if (cut.isEmpty && cutForSearch.isEmpty && links.isEmpty) continue;

      for (final t in cut) {
        searchPostings
            .putIfAbsent(_searchKey(TokenSource.cut, t), () => [])
            .add(diary.isarId);
      }
      for (final t in cutForSearch) {
        searchPostings
            .putIfAbsent(_searchKey(TokenSource.cutForSearch, t), () => [])
            .add(diary.isarId);
      }
      for (final toId in links) {
        linkPostings.putIfAbsent(_linkKey(toId), () => []).add(diary.isarId);
      }
      snapshots.add(
        DiaryIndexSnapshot(
          diaryIsarId: diary.isarId,
          cutTokens: cut,
          cutForSearchTokens: cutForSearch,
          linkToIds: links,
        ),
      );
    }

    final searchRows = [
      for (final e in searchPostings.entries)
        SearchPosting(key: e.key, diaryIsarIds: e.value),
    ];
    final linkRows = [
      for (final e in linkPostings.entries)
        LinkPosting(key: e.key, fromIsarIds: e.value),
    ];
    await _isar.writeAsync((isar) {
      isar.searchPostings.clear();
      isar.linkPostings.clear();
      isar.diaryIndexSnapshots.clear();
      isar.searchPostings.putAll(searchRows);
      isar.linkPostings.putAll(linkRows);
      isar.diaryIndexSnapshots.putAll(snapshots);
    });
    // 任何一次全量重建都完成了升级后的一次性回填（搜索页提示据此收起）。
    await MoodiaryKVs.searchIndexBackfilled.set(true);
    return diaries.length;
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
