import 'dart:async';

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'diary_content_util.dart';

/// 倒排 / 链接索引的建立时机：[inline] 立即建（默认，非编辑器调用方）；[defer] 只写行 +
/// 入队，分词/倒排推迟到排空时建（编辑期内容有变）；[skip] 不建也不入队（编辑期仅改元
/// 数据，内容未变、索引仍有效）。
enum IndexMode { inline, defer, skip }

class DiaryRepository {
  DiaryRepository._(this._isar);

  factory DiaryRepository.get() => _instance;

  static final DiaryRepository _instance = DiaryRepository._(
    IsarDatabase.get().isar,
  );

  final Isar _isar;

  final StreamController<DiaryEvent> _events =
      StreamController<DiaryEvent>.broadcast();

  Stream<DiaryEvent> get diaryEvents => _events.stream;

  Stream<Diary?> watchDiary(int isarId) => _isar.diarys.watchObject(isarId);

  static void _writeIndexEntries(
    Isar isar,
    int diaryIsarId,
    List<String> tokens,
    TokenSource source,
  ) {
    final collection = isar.diarySearchIndexs;
    final entries = tokens
        .map(
          (token) => DiarySearchIndex(
            id: collection.autoIncrement(),
            token: token,
            diaryIsarId: diaryIsarId,
            source: source,
          ),
        )
        .toList();
    collection.putAll(entries);
  }

  static void _removeIndexEntries(Isar isar, int diaryIsarId) {
    final ids = isar.diarySearchIndexs
        .where()
        .diaryIsarIdEqualTo(diaryIsarId)
        .idProperty()
        .findAll();
    isar.diarySearchIndexs.deleteAll(ids);
  }

  // —— 双链反向索引（DiaryLinkIndex）：与搜索倒排索引同范式维护 —— //
  static void _writeLinkEntries(Isar isar, int fromIsarId, List<String> toIds) {
    if (toIds.isEmpty) return;
    final collection = isar.diaryLinkIndexs;
    final entries = toIds
        .map(
          (toId) => DiaryLinkIndex(
            id: collection.autoIncrement(),
            toId: toId,
            fromIsarId: fromIsarId,
          ),
        )
        .toList();
    collection.putAll(entries);
  }

  static void _removeLinkEntries(Isar isar, int fromIsarId) {
    final ids = isar.diaryLinkIndexs
        .where()
        .fromIsarIdEqualTo(fromIsarId)
        .idProperty()
        .findAll();
    isar.diaryLinkIndexs.deleteAll(ids);
  }

  Future<TokenizeResult?> _tokenize(String text) async {
    if (text.isEmpty) return null;
    try {
      return await Tokenizer.tokenize(text: text);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertADiary(Diary diary) async {
    final result = await _tokenize(diary.contentText.trim());
    final links = DiaryContentUtil.extractLinks(diary);
    await _isar.writeAsync((isar) {
      isar.diarys.put(diary);
      if (result != null) {
        _writeIndexEntries(isar, diary.isarId, result.cut, TokenSource.cut);
        _writeIndexEntries(isar, diary.isarId, result.cutForSearch, TokenSource.cutForSearch);
      }
      _writeLinkEntries(isar, diary.isarId, links);
    });
    _events.add(DiaryCreated(diary));
  }

  Future<void> updateADiary({
    Diary? oldDiary,
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
      _removeIndexEntries(isar, newDiary.isarId);
      if (result != null) {
        _writeIndexEntries(isar, newDiary.isarId, result.cut, TokenSource.cut);
        _writeIndexEntries(isar, newDiary.isarId, result.cutForSearch, TokenSource.cutForSearch);
      }
      _removeLinkEntries(isar, newDiary.isarId);
      _writeLinkEntries(isar, newDiary.isarId, links);
    });
  }

  /// 重建单篇日记的搜索 / 链接索引（队列排空时调用），完成后在同一事务出队。幂等：可重复
  /// 调用、可与另一次排空并发（最多多做一遍）；日记已硬删则只出队。
  Future<void> reindexDiary(int diaryIsarId) async {
    final diary = await _isar.diarys.getAsync(diaryIsarId);
    if (diary == null) {
      await _isar.writeAsync((isar) => isar.reindexQueues.delete(diaryIsarId));
      return;
    }
    final result = await _tokenize(diary.contentText.trim());
    final links = DiaryContentUtil.extractLinks(diary);
    await _isar.writeAsync((isar) {
      _removeIndexEntries(isar, diaryIsarId);
      if (result != null) {
        _writeIndexEntries(isar, diaryIsarId, result.cut, TokenSource.cut);
        _writeIndexEntries(isar, diaryIsarId, result.cutForSearch, TokenSource.cutForSearch);
      }
      _removeLinkEntries(isar, diaryIsarId);
      _writeLinkEntries(isar, diaryIsarId, links);
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
  }) async {
    if (categoryId == null) {
      return await _isar.diarys
          .where()
          .showEqualTo(true)          .sortByTimeDesc()
          .findAllAsync(offset: offset, limit: limit);
    } else {
      return await _isar.diarys
          .where()
          .showEqualTo(true)          .categoryIdEqualTo(categoryId)
          .sortByTimeDesc()
          .findAllAsync(offset: offset, limit: limit);
    }
  }

  Future<List<Diary>> getDiaryByMonth(int year, int month) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)        .yMEqualTo('$year/$month')
        .sortByTimeDesc()
        .findAllAsync();
  }

  Future<Diary?> getDiaryByID(int isarId) async {
    return await _isar.diarys.getAsync(isarId);
  }

  Future<Diary?> getDiaryByBusinessId(String id) async {
    return await _isar.diarys.where().idEqualTo(id).findFirstAsync();
  }

  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end, {
    bool all = true,
  }) async {
    return await _isar.diarys
        .where()
        .timeBetween(start, end)
        .showEqualTo(all)        .findAllAsync();
  }

  /// 含回收站的全量日记（同步快照 / dashboard 统计用）。
  Future<List<Diary>> getAllDiaries() async {
    return await _isar.diarys
        .where()        .findAllAsync();
  }

  Future<List<Diary>> getAllDiariesSorted() async {
    return _isar.diarys
        .where()
        .showEqualTo(true)        .sortByTimeDesc()
        .findAllAsync();
  }

  /// 软删除：标记 deleted，清倒排索引，清理本地媒体。
  Future<bool> deleteADiary(int isarId) async {
    final diary = await _isar.diarys.getAsync(isarId);
    if (diary == null) return false;
    await _isar.writeAsync((isar) {
      isar.diarys.put(diary.copyWith(
        deleted: true,
        show: true,
        lastModified: DateTime.timestamp(),
      ));
      _removeIndexEntries(isar, isarId);
      _removeLinkEntries(isar, isarId);
    });
    _events.add(DiaryUpdated(diary.copyWith(deleted: true, show: true)));
    await _cleanLocalMedia(diary);
    return true;
  }

  /// 硬删除（同步引擎推完 tombstone 后调用）。
  Future<void> deleteDiariesByIsarIds(List<int> isarIds) async {
    await _isar.writeAsync((isar) {
      isar.diarys.deleteAll(isarIds);
      for (final id in isarIds) {
        _removeIndexEntries(isar, id);
        _removeLinkEntries(isar, id);
      }
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
        .showEqualTo(false)        .sortByTimeDesc()
        .findAllAsync();
  }

  /// 按类型分页取「在册」日记（排除回收站/墓碑）。
  Future<List<Diary>> getMediaSourceDiaries({
    required MediaType type,
    int? offset,
    int? limit,
  }) async {
    final base = _isar.diarys
        .where()
        .showEqualTo(true)        .deletedEqualTo(false);
    final filtered = switch (type) {
      MediaType.image => base.imageNameIsNotEmpty(),
      MediaType.audio => base.audioNameIsNotEmpty(),
      MediaType.video => base.videoNameIsNotEmpty(),
    };
    return filtered
        .sortByTimeDesc()
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
      final ids = await _isar.diarySearchIndexs
          .where()
          .tokenEqualTo(word)
          .sourceEqualTo(TokenSource.cut)
          .diaryIsarIdProperty()
          .findAllAsync();
      for (final id in ids) {
        scores[id] = (scores[id] ?? 0) + 1.0;
        diaryIdSet.add(id);
      }
    }

    for (final word in cutForSearchTokens) {
      final ids = await _isar.diarySearchIndexs
          .where()
          .tokenEqualTo(word)
          .sourceEqualTo(TokenSource.cutForSearch)
          .diaryIsarIdProperty()
          .findAllAsync();
      for (final id in ids) {
        scores[id] = (scores[id] ?? 0) + 0.5;
        diaryIdSet.add(id);
      }
    }

    final allQueryWords = {...cutTokens, ...cutForSearchTokens};
    for (final word in allQueryWords) {
      final titleMatches = await _isar.diarys
          .where()
          .showEqualTo(true)          .titleContains(word, caseSensitive: false)
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
    final fromIds = await _isar.diaryLinkIndexs
        .where()
        .toIdEqualTo(toId)
        .fromIsarIdProperty()
        .findAllAsync();
    final unique = fromIds.toSet().toList();
    if (unique.isEmpty) return [];
    final diaries = await _isar.diarys.getAllAsync(unique);
    final valid = diaries
        .whereType<Diary>()
        .where((d) => d.show && !d.deleted)
        .toList();
    valid.sort((a, b) => b.time.compareTo(a.time));
    return valid;
  }

  /// 清空并重建全部倒排索引。
  Future<int> rebuildSearchIndex() async {
    final diaries = await getAllDiaries();
    final tokenized = <int, TokenizeResult>{};
    for (final diary in diaries) {
      final text = diary.contentText.trim();
      if (text.isNotEmpty) {
        final result = await _tokenize(text);
        if (result != null) {
          tokenized[diary.isarId] = result;
        }
      }
    }
    await _isar.writeAsync((isar) {
      isar.diarySearchIndexs.clear();
      for (final entry in tokenized.entries) {
        _writeIndexEntries(isar, entry.key, entry.value.cut, TokenSource.cut);
        _writeIndexEntries(isar, entry.key, entry.value.cutForSearch, TokenSource.cutForSearch);
      }
    });
    return diaries.length;
  }

  /// 清空并重建全部双链反向索引（按 `content` 重抽 diaryLink 目标 id）。幂等。
  Future<void> rebuildLinkIndex() async {
    final diaries = await getAllDiaries();
    final links = <int, List<String>>{};
    for (final diary in diaries) {
      final l = DiaryContentUtil.extractLinks(diary);
      if (l.isNotEmpty) links[diary.isarId] = l;
    }
    await _isar.writeAsync((isar) {
      isar.diaryLinkIndexs.clear();
      for (final entry in links.entries) {
        _writeLinkEntries(isar, entry.key, entry.value);
      }
    });
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

    final reindexed = await rebuildSearchIndex();
    await rebuildLinkIndex();
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
