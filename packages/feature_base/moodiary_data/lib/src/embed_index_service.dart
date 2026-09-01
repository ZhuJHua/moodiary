import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'db/database.dart';
import 'db/db_codec.dart';
import 'embed_chunker.dart';

/// 语义检索命中：按日记聚合后的最佳分块。[startOff] 为 -1 表示命中的是标题块。
typedef SemanticHit = ({
  String diaryId,
  double distance,
  int startOff,
  int len,
});

/// 语义索引（本地 RAG）的写与查。设计稿 docs/local-rag.md。
///
/// 索引 = `diary_chunks`（关系真源，drift 表）+ `vec_diary_chunks`（vec0 虚表，
/// 维度随激活模型变，本类经 customStatement 动态建删，rowid 与 chunks.rid 对齐）。
/// 写路径只入队（[DiaryRepository] 各写入口同事务插 `embed_queue`），推理在
/// [drain] 异步完成；硬删的日记同样入队，由 drain 回收孤儿分块——删除与检索之间
/// 的 stale 向量会被 KNN 的 diaries JOIN 天然屏蔽，无正确性问题。
class EmbedIndexService {
  EmbedIndexService._(this._db, this._engine);

  factory EmbedIndexService.get() => _instance ??= EmbedIndexService._(
    MoodiaryDatabase.get(),
    getIt<EmbeddingEngine>(),
  );

  @visibleForTesting
  EmbedIndexService.forTesting(this._db, this._engine);

  static EmbedIndexService? _instance;

  final MoodiaryDatabase _db;
  final SemanticEmbedder _engine;

  /// 每次喂引擎的分块数（限制单次推理时长，排空可被及时打断）。
  static const int _embedBatch = 16;

  bool _draining = false;

  /// 语义索引是否启用（= 有激活的嵌入模型）。未启用时 drain/search 均为 no-op，
  /// 队列自然累积，激活模型后由重建路径清账。
  bool get enabled => _engine.ready;

  // —— 排空 —— //

  /// 排空补嵌队列，返回处理的日记数。[maxDiaries] 限制单次排空量（检索前的
  /// 快速补账传小值；后台排空传 null 走完整队列）。可重入调用直接返回 0。
  Future<int> drain({int? maxDiaries}) async {
    if (!enabled || _draining) return 0;
    _draining = true;
    try {
      if (MoodiaryKVs.embeddingIndexStale.get() ?? false) {
        await _resetForRebuild();
      }
      await _ensureVecTable();
      var processed = 0;
      while (maxDiaries == null || processed < maxDiaries) {
        final batch =
            await (_db.select(_db.embedQueue)
                  ..orderBy([(q) => OrderingTerm.asc(q.enqueuedAt)])
                  ..limit(
                    maxDiaries == null
                        ? _embedBatch
                        : min(_embedBatch, maxDiaries - processed),
                  ))
                .get();
        if (batch.isEmpty) break;
        for (final item in batch) {
          await _reindexOne(item.diaryId);
          processed++;
        }
      }
      return processed;
    } catch (e, s) {
      logger.e('embed drain failed', error: e, stackTrace: s);
      return 0;
    } finally {
      _draining = false;
    }
  }

  /// 全量重建：置 stale 标记后排空（标记驱动 [_resetForRebuild]，中断可续）。
  Future<int> rebuildAll() {
    MoodiaryKVs.embeddingIndexStale.set(true);
    return drain();
  }

  /// 模型停用/删除后的清理：向量与分块整体删除，队列清空。
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.diaryChunks).go();
      await _db.delete(_db.embedQueue).go();
      if (await _vecTableExists()) {
        await _db.customStatement('DROP TABLE vec_diary_chunks');
      }
    });
  }

  // —— 检索 —— //

  /// KNN 语义检索（按日记聚合取最佳分块）。回收站（show=0）与已删日记被 JOIN
  /// 排除；[categoryId]/[start]/[endExclusive] 为 KNN 后过滤，靠 [limit]*4 的
  /// 超采样兜召回。
  Future<List<SemanticHit>> search(
    String query, {
    int limit = 5,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    if (!enabled || !await _vecTableExists()) return const [];
    // 最近编辑还躺在队列里时先小批补账，保证「刚写完就能被助手搜到」。
    if (!_draining) await drain(maxDiaries: 8);

    final qvec = await _engine.embedQuery(query);
    final k = max(limit * 4, 32);
    final filters = StringBuffer();
    final vars = <Variable<Object>>[Variable(_f32Blob(qvec)), Variable(k)];
    if (categoryId != null) {
      filters.write(' AND d.category_id = ?');
      vars.add(Variable(categoryId));
    }
    if (start != null) {
      filters.write(' AND d.time >= ?');
      vars.add(Variable(dbTime(start)));
    }
    if (endExclusive != null) {
      filters.write(' AND d.time < ?');
      vars.add(Variable(dbTime(endExclusive)));
    }
    final rows = await _db
        .customSelect(
          'SELECT v.distance AS distance, c.diary_id AS diary_id, '
          '       c.start_off AS start_off, c.len AS len '
          'FROM vec_diary_chunks v '
          'JOIN diary_chunks c ON c.rid = v.rowid '
          'JOIN diaries d ON d.id = c.diary_id '
          'WHERE v.embedding MATCH ? AND k = ? AND d.show = 1$filters '
          'ORDER BY v.distance',
          variables: vars,
        )
        .get();

    final best = <String, SemanticHit>{};
    for (final row in rows) {
      final id = row.read<String>('diary_id');
      if (best.containsKey(id)) continue;
      best[id] = (
        diaryId: id,
        distance: row.read<double>('distance'),
        startOff: row.read<int>('start_off'),
        len: row.read<int>('len'),
      );
      if (best.length >= limit) break;
    }
    return best.values.toList();
  }

  // —— 内部 —— //

  /// 单篇重嵌：读行 → 分块 → 与旧 hash 比对（未变则只出队）→ 换血。
  /// 推理在事务外；行删插与出队单事务原子。
  Future<void> _reindexOne(String diaryId) async {
    final row =
        await (_db.select(_db.diaries)
              ..where((d) => d.id.equals(diaryId))
              ..limit(1))
            .getSingleOrNull();
    final oldChunks =
        await (_db.select(_db.diaryChunks)
              ..where((c) => c.diaryId.equals(diaryId))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();

    if (row == null) {
      // 日记已硬删：回收分块与向量。
      await _db.transaction(() async {
        await _deleteChunks(diaryId, oldChunks);
        await _dequeue(diaryId);
      });
      return;
    }

    // 分块：seq 0 = 标题（start_off=-1 约定），正文块按偏移。
    final texts = <String>[];
    final spans = <ChunkSpan>[];
    if (row.title.trim().isNotEmpty) {
      texts.add(row.title);
      spans.add((start: -1, len: 0));
    }
    for (final span in chunkOffsets(row.contentText)) {
      texts.add(row.contentText.substring(span.start, span.start + span.len));
      spans.add(span);
    }
    final hashes = [for (final t in texts) _hash(t)];

    final unchanged =
        oldChunks.length == hashes.length &&
        [
          for (var i = 0; i < hashes.length; i++)
            oldChunks[i].textHash == hashes[i],
        ].every((same) => same);
    if (unchanged) {
      await _dequeue(diaryId);
      return;
    }

    final vectors = <Float32List>[];
    for (var i = 0; i < texts.length; i += _embedBatch) {
      vectors.addAll(
        await _engine.embedPassages(
          texts.sublist(i, min(i + _embedBatch, texts.length)),
        ),
      );
    }

    await _db.transaction(() async {
      await _deleteChunks(diaryId, oldChunks);
      for (var i = 0; i < spans.length; i++) {
        final chunk = await _db
            .into(_db.diaryChunks)
            .insertReturning(
              DiaryChunksCompanion.insert(
                diaryId: diaryId,
                seq: i,
                startOff: spans[i].start,
                len: spans[i].len,
                textHash: hashes[i],
              ),
            );
        await _db.customStatement(
          'INSERT INTO vec_diary_chunks(rowid, embedding) VALUES (?, ?)',
          [chunk.rid, _f32Blob(vectors[i])],
        );
      }
      await _dequeue(diaryId);
    });
  }

  Future<void> _deleteChunks(String diaryId, List<DiaryChunkRow> old) async {
    if (old.isEmpty) return;
    if (await _vecTableExists()) {
      await _db.customStatement(
        'DELETE FROM vec_diary_chunks WHERE rowid IN '
        '(SELECT rid FROM diary_chunks WHERE diary_id = ?)',
        [diaryId],
      );
    }
    await (_db.delete(
      _db.diaryChunks,
    )..where((c) => c.diaryId.equals(diaryId))).go();
  }

  Future<void> _dequeue(String diaryId) => (_db.delete(
    _db.embedQueue,
  )..where((q) => q.diaryId.equals(diaryId))).go();

  /// 重建准备：换维度重建 vec 表、清分块、全量 re-enqueue。标记在入队完成后
  /// 清除——之后即使排空中断，队列也会把账还完。
  Future<void> _resetForRebuild() async {
    await _db.transaction(() async {
      if (await _vecTableExists()) {
        await _db.customStatement('DROP TABLE vec_diary_chunks');
      }
      await _db.delete(_db.diaryChunks).go();
      await _db.delete(_db.embedQueue).go();
      await _db.customStatement(
        'INSERT INTO embed_queue(diary_id, enqueued_at) '
        'SELECT id, ? FROM diaries',
        [dbTime(DateTime.timestamp())],
      );
    });
    MoodiaryKVs.embeddingIndexStale.set(false);
  }

  Future<void> _ensureVecTable() async {
    final dim = _engine.dim;
    if (dim <= 0) throw StateError('embeddingDim not set');
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS vec_diary_chunks '
      'USING vec0(embedding float[$dim] distance_metric=cosine)',
    );
  }

  Future<bool> _vecTableExists() async {
    final rows = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'vec_diary_chunks'",
        )
        .get();
    return rows.isNotEmpty;
  }

  static String _hash(String text) => md5.convert(utf8.encode(text)).toString();

  static Uint8List _f32Blob(Float32List v) =>
      v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);
}
